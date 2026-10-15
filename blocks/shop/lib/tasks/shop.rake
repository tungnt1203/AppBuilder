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

namespace :shop do
  desc "Import Printify products (ids as JSON in TASK_INPUT) as drafts and print what happened as JSON"
  task printify_import: :environment do
    ids = Array(JSON.parse(ENV.fetch("TASK_INPUT"))["ids"])
    result = { "imported" => [], "errors" => [] }
    if Store.current.printify_connected?
      ids.each do |id|
        product = Printify::Import.new.call(id)
        result["imported"] << { "id" => id, "title" => product.title, "status" => product.status, "to_check" => product.launch_problems }
      rescue PrintifyGateway::Error, ActiveRecord::RecordInvalid => error
        result["errors"] << "#{id}: #{error.message}"
      end
    else
      result["errors"] << "Printify isn't connected in this shop: save it in /admin Settings first"
    end
    puts "PRINTIFY_IMPORT_RESULT #{result.to_json}"
  end
end
