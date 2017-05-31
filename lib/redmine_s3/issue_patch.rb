module RedmineS3
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        after_save :update_cmis_attachments
        before_destroy :delete_cmis_attachments
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def delete_cmis_attachments
        Rails.logger.debug("delete_cmis_attachments #{}")
        t = Tracker.find(self.tracker_id)
        #nameFolder = t.name + "_" + self.id.to_s + "_" + self.subject
        nameFolder = t.name + "_" + self.id.to_s
        RedmineS3::Connection.deleteFolderByName(nameFolder, true)
      end

      def update_cmis_attachments
        Rails.logger.debug("\n[redmine_cmis_attachments] update_cmis_attachments on issue #{self.id}")
        self.self_and_descendants.each do |d|
          d.attachments.each do |a|
            a.classify
          end
        end
      end

    end
  end
end