module RedmineS3
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        before_update :update_cmis_folder
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
        nameFolder = t.name + "_" + self.id.to_s + "_" + self.subject
        #nameFolder = t.name + "_" + self.id.to_s
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

      def update_cmis_folder
        Rails.logger.debug("\n[redmine_cmis_attachments] update_cmis_folder on issue #{self.id}")
        if !cmis_object_id.nil?
          folder = RedmineS3::Connection.get_folder(cmis_object_id)
          if !folder.nil?
            folder.update_properties('cmis:description'=>self.description)
            folder.update_properties('cm:title'=>self.subject)
          end
        end
        Rails.logger.debug("[redmine_cmis_attachments] issue #{self.id} has cmis_object_id #{cmis_object_id}\n")
      end

      def cmis_object_id
        if self.id
          issue = Issue.find(self.id)
          project = Project.find(issue.project_id)
          t = Tracker.find(self.tracker_id)
          nameFolder = t.name + "_" + self.id.to_s + "_" + self.subject
          folder = RedmineS3::Connection.folder_by_tree_and_name(project.cmis_object_id, nameFolder)
          if !folder.nil?
            return folder.cmis_object_id
          end
        end
        return nil
      end
    end
  end
end