require "net/http"
require "json"
require "date"
require "uri"

class Downloader
  def initialize(space_id, album_id)
    @space_id = space_id
    @album_id = album_id
    @stats = { present: 0, downloaded: 0, failed: 0, deleted: 0 }
  end

  def run
    resp = Net::HTTP.get(URI(asset_url))
    resp = resp.sub("while (1) {}", "")
    assets = JSON.parse(resp)["resources"]

    # Collect expected filenames
    expected_files = []

    assets.each_with_index do |a, i|
      filename = "content/everyday/#{i.to_s.rjust(3, '0')}.jpg"
      expected_files << File.basename(filename)

      # Skip if file already exists and is non-empty
      if File.exist?(filename) && File.size(filename) > 0
        puts "⏭️ #{File.basename(filename)} déjà présente, skip"
        @stats[:present] += 1
        next
      end

      puts "⬇️ Téléchargement de #{File.basename(filename)}"
      url = "https://photos.adobe.io/v2/spaces/#{@space_id}/#{a['asset']['links']['/rels/rendition_type/2048']['href']}"
      data = download_with_retry(url, File.basename(filename))

      if data
        File.open(filename, "wb") { |f| f.write(data) }
        @stats[:downloaded] += 1
      else
        puts "⚠️ Échec téléchargement #{File.basename(filename)} (403/timeout), fichier local conservé si existant"
        @stats[:failed] += 1
      end
    end

    # Clean up obsolete images (no longer in the Lightroom album)
    Dir.glob("content/everyday/*.jpg").each do |local_file|
      basename = File.basename(local_file)
      unless expected_files.include?(basename)
        File.delete(local_file)
        puts "🗑️ #{basename} supprimée (retirée de l'album)"
        @stats[:deleted] += 1
      end
    end

    # Summary
    puts "\nBilan : #{@stats[:present]} présentes, #{@stats[:downloaded]} téléchargées, #{@stats[:failed]} échecs, #{@stats[:deleted]} supprimées"
  end

  def download_with_retry(url, label, max_retries: 2)
    attempts = 0
    loop do
      attempts += 1
      data, code = fetch_following_redirects(url)
      puts "🔍 [DEBUG] #{label} → #{url} → HTTP #{code}"

      if code == 200 && data && !data.empty?
        return data
      end

      if attempts < max_retries
        puts "🔄 Retry #{attempts}/#{max_retries - 1} dans 2s..."
        sleep 2
      else
        return nil
      end
    end
  end

  def fetch_following_redirects(url, redirect_limit: 5)
    raise "Trop de redirections" if redirect_limit == 0

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    response = http.request(request)

    case response
    when Net::HTTPRedirection
      location = response["location"]
      fetch_following_redirects(location, redirect_limit: redirect_limit - 1)
    when Net::HTTPSuccess
      [response.body, response.code.to_i]
    else
      [nil, response.code.to_i]
    end
  end

  def asset_url
    "https://lightroom.adobe.com/v2/spaces/#{@space_id}/albums/#{@album_id}/assets?embed=asset%3Buser&order_after=-&exclude=incomplete&subtype=image%3Bvideo%3Blayout_segment&limit=1000"
  end
end

Downloader.new(ARGV[0], ARGV[1]).run
