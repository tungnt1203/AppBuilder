module Bookings
  class ReplacedCoreFile < StandardError; end

  # Not isolated, like the shop: Service, Appointment… are top-level models of the app, and its
  # views, mailer templates and translations override the engine's when they have the same name.
  class Engine < ::Rails::Engine
    initializer "booking.migrations" do |app|
      config.paths["db/migrate"].expanded.each do |path|
        app.config.paths["db/migrate"] << path unless app.config.paths["db/migrate"].include?(path)
      end
    end

    # A file of the app with the same path as one of the core's would replace the core's class.
    initializer "booking.no_replaced_files" do |app|
      replaced = Dir.glob("app/**/*.rb", base: root).select { |file| app.root.join(file).exist? }
      if replaced.any?
        raise ReplacedCoreFile, "#{replaced.to_sentence} replace#{"s" if replaced.one?} the booking core's code. " \
          "Add to a core model in app/models/<model>/extension.rb instead (see Bookings.extend_model), and delete #{replaced.one? ? "it" : "them"}."
      end
    end
  end
end
