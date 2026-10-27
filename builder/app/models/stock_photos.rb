require "net/http"

# Free stock photos for the studio's Design tab, as the template's bin/images finds them for the
# agent: Unsplash when the builder has its key (config.x.stock_photo_keys), else Openverse,
# which needs none. Unsplash photos stay at Unsplash's address, as its terms ask.
class StockPhotos
  Photo = Data.define(:url, :thumb, :credit, :page, :download)
  REFERRAL = "utm_source=app_builder&utm_medium=referral"

  def self.search(query, count: 9, page: 1)
    new.search(query, count:, page:)
  end

  # Where the photos come from, for the studio to say.
  def self.source
    keys["UNSPLASH_ACCESS_KEY"] ? "Unsplash" : "Openverse"
  end

  # Unsplash counts a photo as used when its download link is called.
  def self.used(download)
    uri = URI(download.to_s)
    return unless uri.host == "api.unsplash.com" && (key = keys["UNSPLASH_ACCESS_KEY"])

    get(uri, "Authorization" => "Client-ID #{key}")
  rescue StandardError => error
    Rails.logger.warn("Unsplash download ping failed: #{error.message}")
  end

  def self.keys
    Rails.configuration.x.stock_photo_keys
  end

  def self.get(uri, headers = {})
    request = Net::HTTP::Get.new(uri, { "User-Agent" => "app-builder-studio" }.merge(headers))
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
    raise "#{uri.host} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def search(query, count:, page: 1)
    return [] if query.to_s.strip.empty?

    self.class.keys["UNSPLASH_ACCESS_KEY"] ? unsplash(query, count, page) : openverse(query, count, page)
  end

  private
    def unsplash(query, count, page)
      params = URI.encode_www_form(query:, page:, per_page: count, content_filter: "high", orientation: "landscape")
      results = self.class.get(URI("https://api.unsplash.com/search/photos?#{params}"), "Authorization" => "Client-ID #{self.class.keys["UNSPLASH_ACCESS_KEY"]}")["results"]
      results.map do |photo|
        Photo.new(url: "#{photo.dig("urls", "raw")}&w=1600&q=80&fm=jpg&fit=max", thumb: photo.dig("urls", "small"),
                  credit: "Photo by #{photo.dig("user", "name")} on Unsplash", page: "#{photo.dig("links", "html")}?#{REFERRAL}",
                  download: photo.dig("links", "download_location"))
      end
    end

    def openverse(query, count, page)
      params = URI.encode_www_form(q: query, page:, license: "cc0,pdm,by", category: "photograph", mature: false, page_size: count, aspect_ratio: "wide")
      self.class.get(URI("https://api.openverse.org/v1/images/?#{params}"))["results"].map do |result|
        license = [ "CC", result["license"].to_s.upcase, result["license_version"] ].compact.join(" ").sub("CC CC0", "CC0").sub("CC PDM", "Public domain")
        Photo.new(url: result["url"], thumb: result["thumbnail"].presence || result["url"],
                  credit: "“#{result["title"].to_s[0, 60].strip}” by #{result["creator"] || "unknown"} (#{license})", page: result["foreign_landing_url"], download: nil)
      end
    end
end
