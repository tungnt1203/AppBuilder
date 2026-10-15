require "ferrum"

# Opens a built app in headless Chrome like its first visitor and its owner would:
# the pages anyone can open (the home page, a product page…), then signed in to /admin, the
# app's main pages (its GET routes without parameters), and then both kinds on a phone.
# Records how each page answered and keeps a full-page screenshot of it.
module Evaluation
  class Inspection
    EMAIL = "eval-owner@example.com"
    PASSWORD = "eval-password-2026"
    MAX_PUBLIC_PAGES = 3
    FIXTURES = Rails.root.join("eval/fixtures")
    MAX_PAGES = 5
    # The starter app's own screens and Rails' internals; the pages the agent made are the point.
    SKIP = %r{\A/(checkout|cart_items|zip_codes|feeds|printify|stripe|rails|up|session|passwords|first_run|invitations|registration|account|_blocks|_preview|cable|assets|recede_historical_location|resume_historical_location|refresh_historical_location|service-worker|manifest|admin/(users|session|passwords|first_run|invitations))(/|\z)}

    Shot = Struct.new(:name, :path, :file, :status, :error, :signed_in, keyword_init: true)

    attr_reader :shots

    # Whether the eval put in the shop's product (see #stock_shop), for the judge to know it isn't
    # the app's.
    def stocked? = @stocked

    def initialize(project, dir)
      @project, @dir = project, dir
      @shots = []
    end

    def call
      @dir.mkpath
      browser = Ferrum::Browser.new(browser_path: Rails.configuration.x.chrome_bin, window_size: [ 1280, 800 ], timeout: 30, process_timeout: 30)
      browser.go_to(@project.preview_gate.entry_url) # past the preview's gate, which keeps a cookie
      stock_shop
      answers = candidate_pages.index_with { |path| answer(path) }.reject { |_path, code| code == 404 } # switched off, like the shop in an app that sells nothing
      public, private = answers.keys.partition { |path| answers[path].between?(200, 299) }
      public.first(MAX_PUBLIC_PAGES).each_with_index { |path, index| visit browser, path, name: "visitor-#{index + 1}", signed_in: false }
      @signed_in = create_owner && sign_in(browser)
      ([ @project.staff_home_path ] + private).uniq.first(MAX_PAGES).each_with_index { |path, index| visit browser, path, name: "page-#{index + 1}", signed_in: @signed_in }
      browser.resize(width: 390, height: 844)
      phone_pages(public, private).each_with_index { |path, index| visit browser, path, name: "phone-#{index + 1}", signed_in: @signed_in }
      self
    ensure
      browser&.quit
    end

    def signed_in?
      @signed_in
    end

    def pages
      { "signed_in" => signed_in?, "visited" => shots.map { |shot| shot.to_h.except(:file).merge(file: shot.file.relative_path_from(@dir.parent.parent).to_s) } }
    end

    private
      def visit(browser, path, name:, signed_in:, full: true)
        browser.go_to(@project.preview_url + path)
        settle browser
        status = browser.network.status
        error = PreviewServer.error_from(browser.body) || "Answered #{status}" if status.to_i >= 400
        file = @dir.join("#{name}.png")
        reveal browser if full
        browser.screenshot(path: file.to_s, full:)
        @shots << Shot.new(name:, path:, file:, status:, error:, signed_in:)
      rescue Ferrum::Error => error
        @shots << Shot.new(name:, path:, file: @dir.join("#{name}.png"), status: nil, error: "#{error.class}: #{error.message}".truncate(500), signed_in:)
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

      # What a customer most likely opens on a phone (a product page, where ads land, rather than the
      # home page), and the owner's main screen.
      def phone_pages(public, private)
        [ public.find { |path| path.start_with?("/products/") } || public.find { |path| path != "/" } || public.first,
          private.first || @project.staff_home_path ].compact.uniq
      end

      # What a visitor who isn't signed in gets: 2xx for a public page, a redirect to sign in for
      # /admin's, 404 for a part of the app that's off. 0 when the app didn't answer.
      def answer(path)
        Net::HTTP.start("127.0.0.1", @project.port, open_timeout: 2, read_timeout: 30) { |http| http.get(path, @project.preview_gate.headers) }.code.to_i
      rescue SystemCallError, IOError, Net::ReadTimeout
        0
      end

      # The owner the app would have after its first run, made directly in the app's database.
      def create_owner
        script = <<~RUBY
          User.find_by(email_address: #{EMAIL.inspect}) ||
            User.create!(name: "Eval Owner", email_address: #{EMAIL.inspect}, password: #{PASSWORD.inspect},
                         role: User.exists?(role: "owner") ? "admin" : "owner")
        RUBY
        @project.sandbox.capture("bin/rails", "runner", script).last
      end

      def sign_in(browser)
        browser.go_to(@project.preview_url + @project.staff_sign_in_path)
        settle browser
        email, password = browser.at_css("input[name='email_address']"), browser.at_css("input[name='password']")
        return false unless email && password

        email.focus.type(EMAIL)
        password.focus.type(PASSWORD, :enter)
        20.times { break unless browser.current_url.include?("/session"); sleep 0.25 }
        settle browser
        !browser.current_url.include?("/session")
      end

      # A shop starts without products until the owner imports theirs from Printify, so one
      # product is put in as an import would (options, prices, costs, a mockup per color, a size
      # guide), for the product page, where ads land, to be seen and judged. Apps without a shop,
      # or with products of their own, are left as they are.
      def stock_shop
        photos = @project.path.join("tmp/eval")
        photos.mkpath
        %w[ tee-black tee-white ].each { |name| FileUtils.cp(FIXTURES.join("#{name}.jpg"), photos.join("#{name}.jpg")) }
        output, = @project.sandbox.capture("bin/rails", "runner", <<~RUBY)
          if defined?(Product) && Rails.configuration.x.try(:shop) != false && Product.where(status: "active").none?
            tee = Product.create!(title: "Classic Tee", status: "active", base_price: "24", printify_product_id: "eval-tee",
              description: "Soft, lightweight cotton tee with a classic fit.\n\n- 100% ring-spun cotton\n- Printed to order",
              option1_name: "Color", option1_values_text: "Black, White", option2_name: "Size", option2_values_text: "S, M, L, XL, 2XL",
              size_guide: "Size | Chest (in) | Length (in)\nS | 18 | 28\nM | 20 | 29\nL | 22 | 30\nXL | 24 | 31\n2XL | 26 | 32")
            tee.variants.each { |variant| variant.update!(cost: "11.50", printify_variant_id: variant.id) }
            tee.variants.where(option2: "2XL").find_each { |variant| variant.update!(price: "27") }
            %w[ black white ].each do |color|
              tee.images.attach(io: File.open("tmp/eval/tee-\#{color}.jpg"), filename: "classic-tee-\#{color}.jpg", content_type: "image/jpeg")
            end
            tee.save!
            puts "stocked"
          end
        RUBY
        @stocked = output.to_s.include?("stocked")
      rescue ProjectShell::Error => error
        Rails.logger.warn "Eval: couldn't add a product to #{@project.slug}: #{error.message.truncate(300)}"
      end

      # The home page first, then a product page when the app sells some (where ads land), then
      # lists, then forms for adding things.
      def candidate_pages
        output, = @project.sandbox.capture("bin/rails", "runner", <<~RUBY)
          paths = Rails.application.routes.routes.filter_map do |route|
            next unless route.verb.to_s.include?("GET")
            path = route.path.spec.to_s.sub("(.:format)", "")
            path unless path.include?(":") || path.include?("*") || path.include?("(")
          end
          product = Product.where(status: "active").first if defined?(Product) && Product.respond_to?(:table_exists?) && Product.table_exists?
          paths.unshift(Rails.application.routes.url_helpers.product_path(product)) if product rescue nil
          puts JSON.generate(paths.uniq)
        RUBY
        paths = JSON.parse(output.lines.reverse.find { |line| line.start_with?("[") } || "[]")
        paths = paths.reject { |path| path.match?(SKIP) }
        ([ "/" ] + paths.reject { |path| path.end_with?("/new") } + paths.select { |path| path.end_with?("/new") }).uniq
      rescue JSON::ParserError
        [ "/" ]
      end
  end
end
