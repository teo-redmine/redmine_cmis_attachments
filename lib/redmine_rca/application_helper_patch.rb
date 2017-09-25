module RedmineRca
  module ApplicationHelperPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development

        alias_method_chain :thumbnail_tag, :rca_patch
      end
    end

    module InstanceMethods
      def thumbnail_tag_with_rca_patch(attachment)
        link_to image_tag(attachment.thumbnail_rca, data: {thumbnail: thumbnail_path(attachment)}),
                RedmineRca::Connection.object_url(attachment.disk_filename),
                title: attachment.filename
      end
    end
  end
end
