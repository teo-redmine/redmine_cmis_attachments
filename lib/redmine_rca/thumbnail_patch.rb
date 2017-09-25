module RedmineRca
  module ThumbnailPatch
    # Generates a thumbnail for the source image to target
    def self.generate_rca_thumb(source, target, size, update_thumb = false)
      target_folder = RedmineRca::Connection.thumb_folder
      if update_thumb
        return unless Object.const_defined?(:Magick)
        require 'open-uri'
        img = Magick::ImageList.new
        url = RedmineRca::Connection.object_url(source)
        open(url, 'rb') do |f| img = img.from_blob(f.read) end
        img = img.strip!
        img = img.resize_to_fit(size)

        RedmineRca::Connection.put(target, File.basename(target), img.to_blob, img.mime_type, target_folder)
      end
      RedmineRca::Connection.object_url(target, target_folder)
    end
  end
end
