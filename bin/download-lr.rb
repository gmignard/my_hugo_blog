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
      `wget -q -O #{filename} #{url}`

      if File.exist?(filename) && File.size(filename) > 0
        @stats[:downloaded] += 1
      else
        puts "⚠️ Échec téléchargement #{File.basename(filename)} (403/timeout), fichier local conservé si existant"
        @stats[:failed] += 1
        # Remove empty file left by failed download, but don't remove a pre-existing valid file
        if File.exist?(filename) && File.size(filename) == 0
          File.delete(filename)
        end
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

  def asset_url
    "https://lightroom.adobe.com/v2/spaces/#{@space_id}/albums/#{@album_id}/assets?embed=asset%3Buser&order_after=-&exclude=incomplete&subtype=image%3Bvideo%3Blayout_segment&limit=1000"
  end
end

Downloader.new(ARGV[0], ARGV[1]).run
