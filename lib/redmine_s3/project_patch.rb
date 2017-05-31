module RedmineS3
  module ProjectPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        after_save :update_cmis_folder
        before_destroy :delete_cmis_folder
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def delete_cmis_folder
        RedmineS3::Connection.delete cmis_object_id unless cmis_object_id.nil?
      end

      def update_cmis_folder
        Rails.logger.debug("\n[redmine_cmis_attachments] update_cmis_folder on project #{self.id}")
        create_folder if cmis_object_id.nil?
        move_folder if parent_cmis_object_id != RedmineS3::Connection.get_parent(cmis_object_id)
        update_description(cmis_object_id)
        Rails.logger.debug("[redmine_cmis_attachments] project #{self.id} has cmis_object_id #{cmis_object_id}\n")
      end

      def create_folder
        #Modificado el identificador de la carpeta que se guarda del proyecto
        #cogia el nombre y daba error, mejor con el identificador unico del proyecto
        #cmis_object_id = RedmineS3::Connection.mkdir(parent_cmis_object_id, self.name)
        cmis_object_id = RedmineS3::Connection.mkdir(parent_cmis_object_id, self.identifier)
        update_description(cmis_object_id)
        RedmineCmisAttachmentsSettings.set_project_param_value(self, "documents_path_base", cmis_object_id)
      end

      def cmis_object_id
        RedmineCmisAttachmentsSettings.get_project_param_value_no_inherit(self, "documents_path_base")
      end

      def parent_cmis_object_id
        return Setting.plugin_redmine_cmis_attachments['documents_path_base'] if self.parent.nil?
        self.parent.create_folder if self.parent.cmis_object_id.nil?
        self.parent.cmis_object_id
      end

      def move_folder
        Rails.logger.debug("[redmine_cmis_attachments] update_folder_location for project #{self.id}\n")
        #RedmineS3::Connection.move cmis_object_id, self.name, parent_cmis_object_id
        RedmineS3::Connection.move cmis_object_id, self.identifier, parent_cmis_object_id, nil, nil, self.identifier
      end

      def update_description(cmis_object_id)
        folder = RedmineS3::Connection.get_folder(cmis_object_id)
        if !folder.nil?
          folder.update_properties('cmis:description'=>self.description)
        end
      end
    end
  end
end
