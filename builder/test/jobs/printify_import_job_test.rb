require "test_helper"

class PrintifyImportJobTest < ActiveJob::TestCase
  test "imports into the app's preview when it isn't published, and keeps what came in" do
    project = projects(:clinic)
    calls = []
    sandbox = Object.new
    sandbox.define_singleton_method(:capture) do |*command, env: {}|
      calls << [ command, env ]
      [ "PRINTIFY_IMPORT_RESULT {\"imported\":[{\"id\":\"pf-1\",\"title\":\"Cat Tee\",\"status\":\"draft\",\"to_check\":[\"no_size_guide\"]}],\"errors\":[]}", true ]
    end
    project.define_singleton_method(:sandbox) { sandbox }

    PrintifyImportJob.perform_now(project, [ "pf-1" ])

    command, env = calls.sole
    assert_equal [ "bin/rails", "shop:printify_import" ], command
    assert_equal({ "ids" => [ "pf-1" ] }, JSON.parse(env["TASK_INPUT"]))
    assert_equal [ "preview", "Cat Tee" ], [ project.reload.printify_import_result["copy"], project.printify_import_result.dig("imported", 0, "title") ]
    assert_enqueued_with(job: OrdersRefreshJob, args: [ project ])
  end
end
