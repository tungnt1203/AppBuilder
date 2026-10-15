namespace :shop do
  desc "Apply the owner's business settings (JSON in TASK_INPUT) and print what happened as JSON"
  task business_settings: :environment do
    settings = JSON.parse(ENV["TASK_INPUT"] || ENV.fetch("BUSINESS_SETTINGS"))
    puts "BUSINESS_SETTINGS_RESULT #{BusinessSettings.new.apply!(settings).to_json}"
  end
end

namespace :shop do
  desc "Print the shop at a glance (OrdersSummary) as JSON, for the owner's builder"
  task orders_summary: :environment do
    puts "ORDERS_SUMMARY_RESULT #{OrdersSummary.new.to_h.to_json}"
  end
end
