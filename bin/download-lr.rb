require "net/http"
require "json"
require "date"
require "uri"

MANIFEST_PATH = "content/everyday/.manifest.json"
CONTENT_DIR   = "content/everyday"

class Downloader
  def initialize(space_id, album_id)
    @space_id = space_id
    @album_id = album_id
    @stats = { present: 0, downloaded: 0, renamed: 0, failed: 0, deleted: 0 }
  end

  def run
    old_manifest, manifest_exists = load_manifest

    resp = Net::HTTP.get(URI(asset_url))
    resp = resp.sub("while (1) {}", "")
    assets = JSON.parse(resp)["resources"]

    new_manifest = {}
    assets.each_with_index do |a, i|
      new_manifest[index_to_filename(i)] = a["asset"]["id"]
    end

    if manifest_exists
      # current_by_id: asset_id => filename, only for files that exist on disk
      current_by_id = {}
      old_manifest.each do |filename, asset_id|
        current_by_id[asset_id] = filename if File.exist?(File.join(CONTENT_DIR, filename))
      end
      run_sync(assets, new_manifest, current_by_id)
    else
      puts "⚠️ Pas de manifest existant, mode migration : téléchargement complet"
      run_migration(assets, new_manifest)
    end

    File.write(MANIFEST_PATH, JSON.pretty_generate(new_manifest))
    puts "📝 Manifest mis à jour (#{new_manifest.size} assets)"
    puts "\nBilan : #{@stats[:present]} présentes, #{@stats[:downloaded]} téléchargées, #{@stats[:renamed]} renommées, #{@stats[:failed]} échecs, #{@stats[:deleted]} supprimées"
  end

  private

  def run_sync(assets, new_manifest, current_by_id)
    # Collect renames needed (old_name != expected_name for the same asset_id)
    renames = []
    assets.each_with_index do |a, i|
      asset_id      = a["asset"]["id"]
      expected_name = index_to_filename(i)
      current_name  = current_by_id[asset_id]
      renames << { asset_id: asset_id, old: current_name, new: expected_name } if current_name && current_name != expected_name
    end

    # Phase 1a: move to temp names to avoid collision chains
    temp_names = {}
    renames.each do |r|
      tmp = "tmp_#{r[:asset_id]}.jpg"
      File.rename(File.join(CONTENT_DIR, r[:old]), File.join(CONTENT_DIR, tmp))
      temp_names[r[:asset_id]] = tmp
    end

    # Phase 1b: move from temp to final names
    renames.each do |r|
      File.rename(File.join(CONTENT_DIR, temp_names[r[:asset_id]]), File.join(CONTENT_DIR, r[:new]))
      puts "🔀 #{r[:old]} → #{r[:new]}"
      @stats[:renamed] += 1
      current_by_id[r[:asset_id]] = r[:new]
    end

    # Phase 2: download missing assets
    assets.each_with_index do |a, i|
      expected_name = index_to_filename(i)
      asset_id      = a["asset"]["id"]

      if current_by_id[asset_id] == expected_name
        puts "⏭️ #{expected_name} déjà à jour, skip"
        @stats[:present] += 1
        next
      end

      puts "⬇️ Téléchargement de #{expected_name}"
      data = download_with_retry(rendition_url(a), expected_name)
      if data
        File.open(File.join(CONTENT_DIR, expected_name), "wb") { |f| f.write(data) }
        @stats[:downloaded] += 1
      else
        puts "⚠️ Échec téléchargement #{expected_name} (403/timeout), fichier local conservé si existant"
        @stats[:failed] += 1
      end
    end

    delete_obsolete(new_manifest, "retirée de l'album")
  end

  def run_migration(assets, new_manifest)
    assets.each_with_index do |a, i|
      filename = index_to_filename(i)
      puts "⬇️ Téléchargement de #{filename} (migration)"
      data = download_with_retry(rendition_url(a), filename)
      if data
        File.open(File.join(CONTENT_DIR, filename), "wb") { |f| f.write(data) }
        @stats[:downloaded] += 1
      else
        puts "⚠️ Échec téléchargement #{filename} (403/timeout), fichier local conservé si existant"
        @stats[:failed] += 1
      end
    end

    delete_obsolete(new_manifest, "hors index API")
  end

  def delete_obsolete(new_manifest, reason)
    Dir.glob("#{CONTENT_DIR}/*.jpg").each do |local_file|
      basename = File.basename(local_file)
      next if new_manifest.key?(basename)
      File.delete(local_file)
      puts "🗑️ #{basename} supprimée (#{reason})"
      @stats[:deleted] += 1
    end
  end

  def load_manifest
    return [{}, false] unless File.exist?(MANIFEST_PATH)
    [JSON.parse(File.read(MANIFEST_PATH)), true]
  rescue JSON::ParserError
    [{}, false]
  end

  def index_to_filename(i)
    "#{i.to_s.rjust(3, '0')}.jpg"
  end

  def rendition_url(asset)
    "https://lightroom.adobe.com/v2/spaces/#{@space_id}/#{asset['asset']['links']['/rels/rendition_type/2048']['href']}"
  end

  def download_with_retry(url, label, max_retries: 2)
    attempts = 0
    loop do
      attempts += 1
      data, code = fetch_following_redirects(url)
      puts "🔍 [DEBUG] #{label} → #{url} → HTTP #{code}"

      return data if code == 200 && data && !data.empty?

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

    uri  = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    response = http.request(request)

    case response
    when Net::HTTPRedirection
      fetch_following_redirects(response["location"], redirect_limit: redirect_limit - 1)
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
