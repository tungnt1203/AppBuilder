module Shop
  # Not isolated: Product, Order, Store… are top-level models of the app, and its views, mailer
  # templates and translations override the engine's when they have the same name.
  class ReplacedCoreFile < StandardError; end

  class Engine < ::Rails::Engine
    # The shop's migrations run with the app's, so an update of the core brings its schema changes.
    initializer "shop.migrations" do |app|
      config.paths["db/migrate"].expanded.each do |path|
        app.config.paths["db/migrate"] << path unless app.config.paths["db/migrate"].include?(path)
      end
    end

    # A file of the app with the same path as one of the core's (app/models/order.rb) would replace
    # the core's class instead of adding to it, and quietly break checkout or payments.
    initializer "shop.no_replaced_files" do |app|
      replaced = Dir.glob("app/**/*.rb", base: root).select { |file| app.root.join(file).exist? }
      if replaced.any?
        raise ReplacedCoreFile, "#{replaced.to_sentence} replace#{"s" if replaced.one?} the shop core's code. " \
          "Add to a core model in app/models/<model>/extension.rb instead (see Shop.extend_model), and delete #{replaced.one? ? "it" : "them"}."
      end
    end
  end
end
