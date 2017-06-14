module RedmineS3
  module AttachmentPatch
    #CONSTANTES con los nombres de los tipos
    PROYECTO_STRING = "Project"
    VERSION_STRING = "Version"
    PETICION_STRING = "Issue"
    NOTICIA_STRING = "News"
    DOCUMENTO_STRING = "Document"
    WIKI_STRING = "WikiPage"
    MENSAJE_STRING = "Message"

    NO_VERSION_FOLDER = "Sin version"

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        attr_accessor :s3_access_key_id, :s3_secret_acces_key, :s3_bucket, :s3_bucket
        after_validation :put_to_s3
        after_create      :generate_thumbnail_s3
        before_destroy   :delete_from_s3
        after_update  :classify
      end
    end

    module ClassMethods
      def find_by_cmis_object_id(cmis_object_id)
       #TODO: check results
        a = Attachment.where("disk_filename = '#{cmis_object_id}'")
        a[0]
      end
    end

    #Modificada la logica de creacion de carpetas para cada tipo
    #se añade la estructura correspondiente en cada uno y se mueve el arhivo
    #a la carpeta final
    module InstanceMethods
      def classify
        Rails.logger.debug("[redmine_cmis_attachments] Classify in #{self.container_type} #{self.container_id}")

        projectIdAux = nil
        issueIdAux = nil
        descriptionAux = self.description
        titleAux = nil
        versionAux = nil

        case
        when self.container_type == PROYECTO_STRING
          projectAux = Project.find(self.container_id)
          projectIdAux = projectAux.identifier
          id_project_folder_cmis = projectAux.cmis_object_id
          id_folder_cmis = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_file_plural).upcase
          target_folder = NO_VERSION_FOLDER

        when self.container_type == VERSION_STRING
          v = Version.find(self.container_id)
          versionAux = v.name
          projectAux = Project.find(v.project_id)
          projectIdAux = projectAux.identifier
          id_project_folder_cmis = projectAux.cmis_object_id
          id_folder_cmis = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_file_plural).upcase
          target_folder = v.name

        when self.container_type == PETICION_STRING
          issueIdAux = self.container_id
          i = Issue.find(self.container_id)
          if i.fixed_version.blank?
            issue_father = i
            while issue_father.parent_id!=nil
              issue_father = Issue.find(issue_father.parent_id)
            end
            descriptionAux = issue_father.subject
            projectAux = Project.find(issue_father.project_id)
            projectIdAux = projectAux.identifier
            id_project_folder_cmis = projectAux.cmis_object_id
            id_folder_cmis = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_issue_plural).upcase
            t = Tracker.find(issue_father.tracker_id)
            target_folder = t.name + "_" + issue_father.id.to_s + "_" + issue_father.subject
            #target_folder = t.name + "_" + issue_father.id.to_s
          else
            versionAux = i.fixed_version.name
            projectAux = Project.find(i.project_id)
            projectIdAux = projectAux.identifier
            id_project_folder_cmis = projectAux.cmis_object_id
            id_folder_cmis = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_issue_plural).upcase
            target_folder = i.fixed_version.name
          end

        when self.container_type == NOTICIA_STRING
          n = News.find(self.container_id)
          projectAux = Project.find(n.project_id)
          projectIdAux = projectAux.identifier
          id_project_folder_cmis = projectAux.cmis_object_id
          cmis_id_folder_wiki = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_news_plural).upcase
          target_folder = DateTime.now.strftime("%Y")
          id_folder_cmis = RedmineS3::Connection.my_create_folder cmis_id_folder_wiki, target_folder
          target_folder = n.title

        when self.container_type == DOCUMENTO_STRING
          d = Document.find(self.container_id)
          dc = DocumentCategory.find(d.category_id)
          descriptionAux = d.description
          titleAux = d.title
          projectAux = Project.find(d.project_id)
          projectIdAux = projectAux.identifier
          id_project_folder_cmis = projectAux.cmis_object_id
          id_folder_cmis = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_document_plural).upcase
          target_folder = dc.name

        when self.container_type == WIKI_STRING
          w = WikiPage.find(self.container_id)
          projectAux = Project.find(w.wiki.project_id)
          projectIdAux = projectAux.identifier
          id_project_folder_cmis = projectAux.cmis_object_id
          #cmis_id_folder_wiki = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_wiki)
          #target_folder = DateTime.now.strftime("%Y")
          #id_folder_cmis = RedmineS3::Connection.my_create_folder cmis_id_folder_wiki, target_folder
          #target_folder = l(DateTime.now.strftime("%B"))
          id_folder_cmis = RedmineS3::Connection.my_create_folder id_project_folder_cmis, l(:label_wiki).upcase
          target_folder = w.title

        when self.container_type == MENSAJE_STRING
          m = Message.find(self.container_id)
          projectAux = Project.find(m.board.project_id)
          projectIdAux = projectAux.identifier
          id_folder_cmis = projectAux.cmis_object_id
          target_folder = l(:label_message_plural).upcase
        end

        document_type = Setting.plugin_redmine_cmis_attachments["document_type"]

        propertiesAux = Hash.new
        propertiesAux['cmis:description'] = descriptionAux

        Rails.logger.info('Usando tipo documental ' + document_type.to_s)
        if document_type != nil && document_type != '' && document_type != 'cmis:document'
          # Se introducen en el mapa los metadatos personalizados
          propertiesAux['teo:id_proyecto'] = projectIdAux.to_s
          propertiesAux['teo:id_peticion'] = nil
          if issueIdAux != nil && issueIdAux != ''
            propertiesAux['teo:id_peticion'] = '#' + issueIdAux.to_s
          end
          propertiesAux['teo:titulo'] = titleAux
          propertiesAux['teo:version'] = versionAux
        end

        RedmineS3::Connection.move(self.disk_filename, self.filename, id_folder_cmis, target_folder, propertiesAux)
      end

      def attachment_of
        case
        when self.container_type == PROYECTO_STRING
          return  Project.find(self.container_id)
        when self.container_type == PETICION_STRING
          return Issue.find(self.container_id)
        end
      end

      def link_to_attachment_of
        controllerAux = 'issues'
        case
        when self.container_type == PROYECTO_STRING
          controllerAux = 'projects'
        when self.container_type == PETICION_STRING
          controllerAux = 'issues'
        end
        attachment_map = Hash.new
        attachment_map[:controller] = controllerAux
        attachment_map[:action] = 'show'
        attachment_map[:id] = self.container_id
        return attachment_map
      end

      def put_to_s3
        if @temp_file && (@temp_file.size > 0) && errors.blank?
          self.disk_directory = RedmineS3::Connection.repository.server.inspect
          Rails.logger.debug("Uploading #{self.filename}, #{@container}")
          self.disk_filename = RedmineS3::Connection.put(self.filename, @temp_file, self.content_type)
          self.digest = Time.now.to_i.to_s
        end
        @temp_file = nil # so that the model's original after_save block skips writing to the fs
      end

      #Borrado de archivos y carpetas que se encuentran vacias hasta el nivel indicado por la padre
      def delete_from_s3
        files_folder = l(:label_file_plural).upcase
        issues_folder = l(:label_issue_plural).upcase
        news_folder = l(:label_news_plural).upcase
        documents_folder = l(:label_document_plural).upcase
        wikis_folder = l(:label_wiki).upcase
        messages_folder = l(:label_message_plural).upcase
        Rails.logger.debug("Deleting #{self.filename}, #{self.disk_filename}")
        foldersRoot = Array[files_folder,issues_folder,news_folder,documents_folder,wikis_folder,messages_folder]
        foldersFathers = RedmineS3::Connection.obtain_cmis_folders(self.disk_filename, foldersRoot)
        RedmineS3::Connection.delete(self.disk_filename)
        if(foldersFathers != nil && foldersFathers.any?)
          for i in 0..(foldersFathers.length-1)
            RedmineS3::Connection.deleteFolder(foldersFathers[i].cmis_object_id, false)
          end
        end
      end

      # Prevent file uploading to the file system to avoid change file name
      def files_to_final_location; end

      # Returns the full path the attachment thumbnail, or nil
      # if the thumbnail cannot be generated.
      def thumbnail_s3(options = {})
        return unless thumbnailable?
        size = options[:size].to_i
        if size > 0
          # Limit the number of thumbnails per image
          size = (size / 50) * 50
          # Maximum thumbnail size
          size = 800 if size > 800
        else
          size = Setting.thumbnails_size.to_i
        end
        size         = 100 unless size > 0
        target       = "#{id}_#{digest}_#{size}.thumb"
        update_thumb = options[:update_thumb] || false
        begin
          RedmineS3::ThumbnailPatch.generate_s3_thumb(self.disk_filename, target, size, update_thumb)
        rescue => e
          logger.error "An error occured while generating thumbnail for #{disk_filename} to #{target}\nException was: #{e.message}" if logger
          return
        end
      end

      def generate_thumbnail_s3
        Rails.logger.debug("[redmine_cmis_attachments] Generating thumbnail, #{@container}")
        thumbnail_s3(update_thumb: true)
      end

      #stubs for browsing
      def name
        self.filename
      end

      def version
        begin
          self.disk_filename.split("\;")[1]
        rescue Exception => e
          ""
        end
      end

     def display_name
       self.filename
     end

     def size
       self.filesize
     end

     def updated_at
        self.created_on
     end

     def comment
       self.description
     end

     def iversion
       "iversion-stub"
     end

      def locked_for_user?
        false
      end

      def locked?
        false
      end

      def items
        0
      end

      def user
        User.find(self.author_id)
      end

      def notification
        false
      end

      def last_revision
        self
      end

      def detect_content_type
        self.content_type
  #RedmineS3::Connection.content_type(self.disk_filename)
      end

      def cmis_name
        cmis_name = RedmineS3::Connection.get_cmis_name(self.disk_filename)
      end
    end
  end
end
