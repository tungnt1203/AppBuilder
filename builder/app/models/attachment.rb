# A file the owner sends with a message (a logo, photos, a menu as PDF, a screenshot of
# an app they like). It's kept in the project's tmp/attachments/<message id>/, where
# the agent can look at it, and listed in the message's data. tmp/ isn't part of the
# app, so the agent copies what the app should use.
class Attachment
  MAX_FILES = 10
  MAX_SIZE = 20.megabytes
  TYPES = %r{\A(image/(png|jpeg|gif|webp|svg\+xml)|application/pdf|text/(plain|csv))\z}

  attr_reader :name, :content_type, :size

  def self.folder(message)
    message.project.path.join("tmp/attachments", message.id.to_s)
  end

  # Keeps the files that are allowed and returns them; the rest are left out.
  def self.save(message, uploads)
    uploads = Array(uploads).select { |upload| upload.respond_to?(:original_filename) && upload.size <= MAX_SIZE && upload.content_type.to_s.match?(TYPES) }
    folder(message).mkpath if uploads.any?

    uploads.first(MAX_FILES).map do |upload|
      name = unique_name(folder(message), safe_name(upload.original_filename))
      FileUtils.cp(upload.tempfile.path, folder(message).join(name))
      new(message, "name" => name, "content_type" => upload.content_type, "size" => upload.size)
    end
  end

  def self.for(message)
    Array(message.data["attachments"]).map { |data| new(message, data) }
  end

  def self.safe_name(filename)
    base = File.basename(filename.to_s).unicode_normalize(:nfc).gsub(/[^\p{L}\p{N}._ -]/, "_").squish
    base.presence&.delete_prefix(".") || "file"
  end

  def self.unique_name(folder, name)
    candidate, counter = name, 1
    candidate = "#{File.basename(name, ".*")}-#{counter += 1}#{File.extname(name)}" while folder.join(candidate).exist?
    candidate
  end

  def initialize(message, data)
    @message = message
    @name, @content_type, @size = data.values_at("name", "content_type", "size")
  end

  def path
    self.class.folder(@message).join(name)
  end

  # Where the agent finds it, from the app's folder.
  def relative_path
    path.relative_path_from(@message.project.path).to_s
  end

  def image?
    content_type.to_s.start_with?("image/")
  end

  def to_h
    { "name" => name, "content_type" => content_type, "size" => size }
  end
end
