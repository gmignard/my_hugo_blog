require "net/http"
require "json"
require "date"
require "uri"

class Downloader
  def initialize(space_id, album_id)
    @space_id = space_id
    @album_id = album_id
  end

  def run
    resp = Net::HTTP.get(URI(asset_url))
    resp = resp.sub("while (1) {}", "")
    assets = JSON.parse(resp)["resources"]
    saved = 0
    skipped = 0

    assets.each_with_index do |a, i|
      filename = "content/everyday/#{i.to_s.rjust(3, "0")}.jpg"
      href = a["asset"]["links"]["/rels/rendition_type/2048"]["href"]
      url = "https://photos.adobe.io/v2/spaces/#{@space_id}/#{href}"

      response = fetch_with_redirects(url)

      unless response.is_a?(Net::HTTPSuccess)
        warn "WARNING: HTTP #{response.code} for image #{i} (#{url}), skipping"
        skipped += 1
        next
      end

      body = response.body
      if body.nil? || body.bytesize == 0
        warn "WARNING: Empty response body for image #{i} (#{url}), skipping"
        skipped += 1
        next
      end

      File.binwrite(filename, body)

      if File.size(filename) == 0
        warn "WARNING: File is 0 bytes after write for image #{i} (#{url}), deleting"
        File.delete(filename)
        skipped += 1
        next
      end

      width, height = image_dimensions(filename)
      if width == 0 || height == 0
        warn "WARNING: Invalid dimensions #{width}x#{height} for image #{i} (#{url}), deleting"
        File.delete(filename)
        skipped += 1
        next
      end

      saved += 1
      puts "Saved image #{i}: #{width}x#{height}"
    end

    puts "Done: #{saved} saved, #{skipped} skipped"
  end

  private

  def fetch_with_redirects(url, limit = 10)
    raise ArgumentError, "Too many HTTP redirects for #{url}" if limit == 0

    uri = URI(url)
    response = Net::HTTP.get_response(uri)

    case response
    when Net::HTTPSuccess
      response
    when Net::HTTPRedirection
      fetch_with_redirects(response["location"], limit - 1)
    else
      response
    end
  end

  def image_dimensions(filename)
    output = `identify -format "%wx%h" "#{filename}" 2>/dev/null`.strip
    return [0, 0] if output.empty?

    parts = output.split("x")
    return [0, 0] unless parts.length == 2

    width = Integer(parts[0]) rescue 0
    height = Integer(parts[1]) rescue 0
    [width, height]
  end

  def asset_url
    "https://lightroom.adobe.com/v2/spaces/#{@space_id}/albums/#{@album_id}/assets?embed=asset%3Buser&order_after=-&exclude=incomplete&subtype=image%3Bvideo%3Blayout_segment&limit=1000"
  end
end

Downloader.new(ARGV[0], ARGV[1]).run
