require "open3"

# A screenshot of the project's preview, shown on its card in the apps grid.
class Thumbnail
  SIZE = "1280,800"
  TIMEOUT = 20 # seconds

  def initialize(project)
    @project = project
  end

  def path
    Rails.configuration.x.thumbnails_root.join("#{@project.slug}.png")
  end

  def exist?
    path.exist?
  end

  def version
    path.mtime.to_i if exist?
  end

  # Opens the preview's home page in headless Chrome and keeps the picture. Without
  # Chrome, or when the page can't be captured, the card keeps its previous picture.
  def capture
    return false unless File.executable?(chrome)

    path.dirname.mkpath
    shot = partial_path
    Dir.mktmpdir("thumbnail") do |profile|
      command = [ chrome, "--headless", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--user-data-dir=#{profile}",
                  "--window-size=#{SIZE}", "--virtual-time-budget=3000", "--screenshot=#{shot}", @project.preview_url ]
      run(command)
    end
    return false unless shot.exist? && shot.size.positive?

    shot.rename(path)
    true
  ensure
    shot&.delete if shot&.exist?
  end

  def delete
    [ path, partial_path ].each { |file| file.delete if file.exist? }
  end

  private
    def partial_path
      path.sub_ext(".tmp.png")
    end

    # Chrome sometimes hangs on a page that never settles; it is stopped after TIMEOUT.
    def run(command)
      Open3.popen2e(*command, pgroup: true) do |stdin, output, waiter|
        stdin.close
        drain = Thread.new { output.read }
        unless waiter.join(TIMEOUT)
          Process.kill("TERM", -waiter.pid)
          waiter.join(2) || Process.kill("KILL", -waiter.pid)
        end
        drain.join
      end
    rescue Errno::ESRCH
    end

    def chrome
      Rails.configuration.x.chrome_bin.to_s
    end
end
