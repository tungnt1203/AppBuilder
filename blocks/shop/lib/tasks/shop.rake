namespace :shop do
  desc "Apply the owner's business settings (JSON in BUSINESS_SETTINGS) and print what happened as JSON"
  task business_settings: :environment do
    settings = JSON.parse(ENV.fetch("BUSINESS_SETTINGS"))
    puts "BUSINESS_SETTINGS_RESULT #{BusinessSettings.new.apply!(settings).to_json}"
  end
end
