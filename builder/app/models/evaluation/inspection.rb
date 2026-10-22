require "ferrum"

# Opens a built storefront in headless Chrome like its first visitors would: the home page, a
# product page and the storefront's other pages (its GET routes without parameters), then the
# ones buyers most likely open on a phone. Records how each page answered and keeps a full-page
# screenshot of it. The owner's screens are the Platform's admin, not the storefront's.
module Evaluation
  class Inspection
    MAX_PAGES = 5
    # The storefront's buying steps and Rails' internals; the pages the agent made are the point.
    SKIP = %r{\A/(checkout|cart_items|zip_codes|feeds|rails|up|_blocks|_preview|cable|assets|recede_historical_location|resume_historical_location|refresh_historical_location|service-worker|manifest)(/|\z)}

    Shot = Struct.new(:name, :path, :file, :status, :error, keyword_init: true)

    attr_reader :shots

    # Whether the eval put in the shop's products (see #stock_shop), for the judge to know it isn't
    # the storefront's.
    def stocked? = @stocked

    def initialize(project, dir)
      @project, @dir = project, dir
      @shots = []
    end

    def call
      @dir.mkpath
      browser = Ferrum::Browser.new(browser_path: Rails.configuration.x.chrome_bin, window_size: [ 1280, 800 ], timeout: 30, process_timeout: 30)
      browser.go_to(@project.preview_gate.entry_url) # past the preview's gate, which keeps a cookie
      product = stock_shop
      answers = candidate_pages(product).index_with { |path| answer(path) }
      pages = answers.keys.select { |path| answers[path].between?(200, 299) }
      pages.first(MAX_PAGES).each_with_index { |path, index| visit browser, path, name: "page-#{index + 1}" }
      browser.resize(width: 390, height: 844)
      phone_pages(pages).each_with_index { |path, index| visit browser, path, name: "phone-#{index + 1}" }
      self
    ensure
      browser&.quit
    end

    def pages
      { "visited" => shots.map { |shot| shot.to_h.except(:file).merge(file: shot.file.relative_path_from(@dir.parent.parent).to_s) } }
    end

    private
      def visit(browser, path, name:, full: true)
        browser.go_to(@project.preview_url + path)
        settle browser
        status = browser.network.status
        error = PreviewServer.error_from(browser.body) || "Answered #{status}" if status.to_i >= 400
        file = @dir.join("#{name}.png")
        reveal browser if full
        browser.screenshot(path: file.to_s, full:)
        @shots << Shot.new(name:, path:, file:, status:, error:)
      rescue Ferrum::Error => error
        @shots << Shot.new(name:, path:, file: @dir.join("#{name}.png"), status: nil, error: "#{error.class}: #{error.message}".truncate(500))
      end

      def settle(browser)
        browser.network.wait_for_idle(timeout: 5)
        sleep 0.5 # transitions and images
      rescue Ferrum::TimeoutError
      end

      # Content that fades in as it scrolls into view would be blank in a full-page picture.
      def reveal(browser)
        height = browser.evaluate("document.documentElement.scrollHeight").to_i
        (0..height).step(400).first(40).each { |y| browser.execute("window.scrollTo({ top: #{y}, behavior: 'instant' })"); sleep 0.08 }
        browser.execute("window.scrollTo({ top: 0, behavior: 'instant' })") # not smooth: a page that scrolls smoothly isn't back at the top yet
        sleep 0.4
      rescue Ferrum::Error
      end

      # What a buyer most likely opens on a phone: a product page, where ads land, and the home page.
      def phone_pages(pages)
        [ pages.find { |path| path.start_with?("/products/") }, "/" ].compact.select { |path| pages.include?(path) }
      end

      # 2xx for a page a visitor can open, 0 when the storefront didn't answer.
      def answer(path)
        Net::HTTP.start("127.0.0.1", @project.port, open_timeout: 2, read_timeout: 30) { |http| http.get(path, @project.preview_gate.headers) }.code.to_i
      rescue SystemCallError, IOError, Net::ReadTimeout
        0
      end

      # A shop starts without products until the owner imports theirs from Printify, so the demo
      # products (DemoCatalog: six with mockups, options, prices and a size guide, in two
      # collections) are put in its shop on the Platform, for the grids, collections and product
      # page, where ads land, to be seen and judged full. A shop with products of its own is left as
      # it is. Returns the product to open: the demo tee, which has colors, sizes and a size guide.
      def stock_shop
        shop = @project.shop or return
        ActsAsTenant.with_tenant(shop) do
          return Product.visible.first if Product.visible.exists?

          DemoCatalog.add!
          @stocked = true
          Product.where(demo: true).order(:id).first
        end
      rescue ActiveRecord::ActiveRecordError => error
        Rails.logger.warn "Eval: couldn't add the demo products to #{@project.slug}'s shop: #{error.message.truncate(300)}"
        nil
      end

      # The home page first, then the product's page (where ads land), then the storefront's
      # other pages, then forms.
      def candidate_pages(product)
        output, = @project.sandbox.capture("bin/rails", "runner", <<~RUBY)
          paths = Rails.application.routes.routes.filter_map do |route|
            next unless route.verb.to_s.include?("GET")
            path = route.path.spec.to_s.sub("(.:format)", "")
            path unless path.include?(":") || path.include?("*") || path.include?("(")
          end
          puts JSON.generate(paths.uniq)
        RUBY
        paths = JSON.parse(output.lines.reverse.find { |line| line.start_with?("[") } || "[]")
        paths = paths.reject { |path| path.match?(SKIP) }
        paths.unshift("/products/#{product.to_param}") if product
        ([ "/" ] + paths.reject { |path| path.end_with?("/new") } + paths.select { |path| path.end_with?("/new") }).uniq
      rescue JSON::ParserError
        [ "/" ]
      end
  end
end
