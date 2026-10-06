require "test_helper"

class ProjectCodeTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root
    @project = projects(:clinic)
    @project.path.mkpath

    git "init", "--quiet", "--initial-branch=main"
    write "app/models/patient.rb" => "class Patient\nend\n", "README.md" => "Hi\n", "old.rb" => "old\n"
    git "add", "--all"
    git "commit", "--quiet", "-m", "Set up"
    write "app/models/patient.rb" => "class Patient\n  has_many :visits\nend\n", "app/models/visit.rb" => "class Visit\nend\n"
    @project.path.join("old.rb").delete
    git "add", "--all"
    git "commit", "--quiet", "-m", "Add visits"
  end

  teardown do
    Rails.configuration.x.projects_root = @original_root
    FileUtils.rm_rf(@root)
  end

  test "lists files as a tree" do
    assert_equal %w[ README.md app/models/patient.rb app/models/visit.rb ], @project.code.paths
    assert_equal({ "README.md" => "README.md", "app" => { "models" => { "patient.rb" => "app/models/patient.rb", "visit.rb" => "app/models/visit.rb" } } }, @project.code.tree)
  end

  test "the latest version's changes, with the lines it added" do
    code = @project.code

    assert_equal({ "app/models/patient.rb" => "changed", "app/models/visit.rb" => "added", "old.rb" => "deleted" }, code.changes)
    assert_equal [ 2 ], code.read("app/models/patient.rb").added_lines.to_a
    assert code.read("app/models/visit.rb").added_lines.include?(2)
    assert_empty code.read("README.md").added_lines
  end

  test "while the agent works, changes since the last version, including new files" do
    @project.update!(status: :working)
    write "README.md" => "Hi\nThere\n", "app/models/doctor.rb" => "class Doctor\nend\n"

    assert_equal({ "README.md" => "changed", "app/models/doctor.rb" => "added" }, @project.code.changes)
    assert_equal [ 2 ], @project.code.read("README.md").added_lines.to_a
  end

  test "only files in the project can be read, and binary files aren't shown" do
    assert_raises(ActiveRecord::RecordNotFound) { @project.code.read("../secrets.txt") }
    write "logo.png" => "\x89PNG\0\0".b

    assert @project.code.read("logo.png").binary?
  end

  private
    def write(files)
      files.each { |path, content| @project.path.join(path).tap { |file| file.dirname.mkpath }.binwrite(content) }
    end

    def git(*args)
      ProjectShell.new(@project.path).run("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", *args)
    end
end
