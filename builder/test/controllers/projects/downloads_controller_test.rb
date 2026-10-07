require "test_helper"

class Projects::DownloadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @root = Pathname(Dir.mktmpdir)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root
    @project = projects(:clinic)
    @project.path.mkpath
    @project.path.join("app.rb").write("puts :hi\n")
    @project.path.join("secret.log").write("not committed\n")
    git = [ "git", "-C", @project.path.to_s, "-c", "user.name=t", "-c", "user.email=t@t" ]
    system(*git, "init", "-q") && system(*git, "add", "app.rb") && system(*git, "commit", "-qm", "First")
    sign_in_as users(:owner)
  end

  teardown do
    Rails.configuration.x.projects_root = @original_root
    @root.rmtree
  end

  test "the code of the latest version, in a folder named after the app" do
    get project_download_path(@project)

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match %(filename="#{@project.archive_name}.zip"), response.headers["Content-Disposition"]
    names = Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "app.zip"), response.body)
      `unzip -Z1 #{File.join(dir, "app.zip")}`.split
    end
    assert_equal [ "#{@project.archive_name}/", "#{@project.archive_name}/app.rb" ], names
  end
end
