module RedmineRca
  module NewsPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        #after_save :update_cmis_folder
#        before_update :update_cmis_folder
        before_destroy :delete_cmis_folder
        after_save :update_cmis_attachments
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def update_cmis_attachments
        Rails.logger.debug("\n[redmine_cmis_attachments] update_cmis_attachments on news #{self.id}")
        self.attachments.each do |a|
          a.classify
        end
      end

      def delete_cmis_folder
        RedmineRca::Connection.delete cmis_object_id unless cmis_object_id.nil?
      end

#      def update_cmis_folder
#        Rails.logger.debug("\n[redmine_cmis_attachments] update_cmis_folder on news #{self.id}")
#        if !cmis_object_id.nil?
#          folder = RedmineRca::Connection.get_folder(cmis_object_id)
#          if !folder.nil?
#            folder.update_properties('cmis:name'=>self.title)
#          end
#        end
#        Rails.logger.debug("[redmine_cmis_attachments] news #{self.id} has cmis_object_id #{cmis_object_id}\n")
#      end

      #def create_folder
      #  Modificado el identificador de la carpeta que se guarda del proyecto
      #  cogia el nombre y daba error, mejor con el identificador unico del proyecto
      #  cmis_object_id = RedmineRca::Connection.mkdir(parent_cmis_object_id, self.name)
      #  RedmineCmisAttachmentsSettings.set_project_param_value(self, "documents_path_base", cmis_object_id)
      #end

      def cmis_object_id
        if self.id
          news = News.find(self.id)
          project = Project.find(news.project_id)
          folder = RedmineRca::Connection.folder_by_tree_and_name(project.cmis_object_id, news.title)
          if !folder.nil?
            return folder.cmis_object_id
          end
        end
        return nil
      end

      #def parent_cmis_object_id
      #  RedmineRca::Connection.get_parent(cmis_object_id)
      #end

      #def move_folder
      #  Rails.logger.debug("[redmine_cmis_attachments] update_folder_location for project #{self.id}\n")
      #  RedmineRca::Connection.move cmis_object_id, self.title, parent_cmis_object_id, nil, nil, nil
      #end
    end
  end
end
