require "test_helper"

class ProjectAddressTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { @project = projects(:clinic) }

  test "before the first publish, the owner just picks the address" do
    assert_no_enqueued_jobs(only: MoveJob) { assert @project.change_subdomain(" Rang-Dep ") }

    assert_equal "rang-dep.localhost", @project.reload.publish_host
    assert @project.ready?
  end

  test "a published app moves in a job and keeps its address until it's there" do
    @project.deployments.create!(status: :live)

    assert_enqueued_with(job: MoveJob, args: [ @project, "rang-dep" ]) { assert @project.change_subdomain("rang-dep") }

    assert_equal "nha-khoa", @project.reload.subdomain
    assert @project.working?
    assert_equal "Moving to rang-dep.localhost", @project.activity
  end

  test "addresses must be valid hostnames, free and not reserved" do
    [ "-rang", "rang-", "răng", "rang dep", "a" * 64, "www", "shop" ].each do |subdomain|
      assert_not @project.change_subdomain(subdomain), subdomain
      assert_equal "nha-khoa", @project.reload.subdomain
    end
  end

  test "keeping the same address does nothing" do
    @project.deployments.create!(status: :live)

    assert_no_enqueued_jobs(only: MoveJob) { assert @project.change_subdomain("NHA-KHOA") }
  end

  test "the move points ONCE at the new host, then the record follows" do
    commands = []
    shell = Object.new
    shell.define_singleton_method(:run) { |*command| commands << command; "" }
    @project.define_singleton_method(:shell) { shell }
    @project.update!(status: :working)

    MoveJob.perform_now(@project, "rang-dep")

    assert_equal [ [ "once", "update", "nha-khoa.localhost", "--host", "rang-dep.localhost" ] ], commands
    assert_equal "rang-dep", @project.reload.subdomain
    assert @project.ready?
    assert_match "Links to nha-khoa.localhost no longer work", @project.messages.last.body
  end

  test "a failed move leaves the app where it was" do
    shell = Object.new
    shell.define_singleton_method(:run) { |*| raise ProjectShell::Error, "once update failed" }
    @project.define_singleton_method(:shell) { shell }
    @project.update!(status: :working)

    MoveJob.perform_now(@project, "rang-dep")

    assert_equal "nha-khoa", @project.reload.subdomain
    assert @project.ready?
    assert_equal "error", @project.messages.last.role
    assert_match "still at nha-khoa.localhost", @project.messages.last.body
  end
end
