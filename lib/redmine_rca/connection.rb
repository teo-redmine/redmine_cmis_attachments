require 'cmis'

module RedmineRca
  class Connection
    @@repository = nil
    CMIS_FOLDER = 'cmis:folder';

    class << self
      def establish_connection
        begin
          config = Setting.plugin_redmine_cmis_attachments
          Rails.logger.debug("[redmine_cmis_attachments] Setting up #{config}")
          server = CMIS::Server.new(service_url: config["server_url"],
            username: config['server_login'],
            password: config['server_password'])
          @@repository = server.repository(config['repository_id'])
          Rails.logger.debug("[redmine_cmis_attachments] Created #{server}, #{@@repository}")
          @@repository
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error estableciendo conexión. Causa: " + e.to_s)
          return nil
        end
      end

      def repository
        begin
          @@repository || establish_connection
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error obteniendo el repositorio: " + e.to_s)
          return nil
        end
      end

      def create_bucket
        #TODO Create if missing
        nil
      end

      def proxy?
        config = Setting.plugin_redmine_cmis_attachments
        config['proxy']
        true
      end

      def put(original_filename, data, content_type='application/octet-stream', target_folder = self.temp_folder)
        Rails.logger.debug("[redmine_cmis_attachments] Creating #{original_filename}")
        begin
          timestamp = nil
          random = nil
          name = original_filename
          5.times do
            begin
              document = self.repository.new_document
              document.object_type_id = 'cmis:document'

              document_type = Setting.plugin_redmine_cmis_attachments["document_type"]

              Rails.logger.info('Usando tipo documental ' + document_type.to_s)
              if document_type != nil && document_type != '' && document_type != 'cmis:document'
                document.object_type_id = 'D:' + document_type

                # Se rellenan parte de los metadatos personalizados,
                # el resto se incluirán al confirmar la subida del archivo
                propertiesAux = Hash.new
                propertiesAux["teo:nombre_usuario_teo"] = User.current.firstname
                propertiesAux["teo:apellidos_usuario_teo"] = User.current.lastname
                propertiesAux["teo:id_usuario_teo"] = User.current.login
                document.update_properties(propertiesAux)
              end

              document.content = { stream: data }
              document.name = name

              saved_document = document.create_in_folder( self.repository.object(target_folder) )
            rescue CMIS::Exceptions::ContentAlreadyExists
              #TODO: further check if it's a duplicate name exception
              Rails.logger.error("[redmine_cmis_attachments] Duplicate name exception captured")
              name = rename_file name
            end
            return saved_document.cmis_object_id unless saved_document.nil?
          end
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error guardando documento. Causa: " + e.to_s)
        end
        raise "Unable to find unique name"
      end

      def delete(cmis_object_id)
        begin
          self.repository.object(cmis_object_id).delete
        rescue CMIS::Exceptions::ObjectNotFound
          Rails.logger.error("[redmine_cmis_attachments] Trying to erase inexistent object #{filename}")
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error eliminando objeto. Causa: " + e.to_s)
          return nil
        end
      end

      def delete_with_children(cmis_object_id)
        begin
          if !self.repository.object(cmis_object_id).children.nil? && self.repository.object(cmis_object_id).children.total > 0
            children = self.repository.object(cmis_object_id).children
            children.each_child(:limit => 1000) do |c|
              Rails.logger.debug("...erasing child " + c.cmis_object_id)
              delete_with_children(c.cmis_object_id)
            end
          end
          Rails.logger.debug("...erasing parent " + cmis_object_id)
          self.repository.object(cmis_object_id).delete
        rescue CMIS::Exceptions::ObjectNotFound
          Rails.logger.error("[redmine_cmis_attachments] Trying to erase inexistent object #{filename}")
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error eliminando objeto. Causa: " + e.to_s)
          return nil
        end
      end

      def object_url(cmis_object_id, target_folder = self.folder)
        Rails.logger.debug("[redmine_cmis_attachments] Looking up object url")
        # TODO: assert is document
        self.repository.object(cmis_object_id).content_url
      end

      # Obtiene documento
      def get(cmis_object_id, target_folder = nil)
        Rails.logger.debug("[redmine_cmis_attachments] Getting object")
        begin
          self.repository.object(cmis_object_id).content
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error obteniendo objeto. Causa: " + e.to_s)
          return nil
        end
      end

      # Obtiene carpeta
      def get_folder(cmis_object_id)
        Rails.logger.debug("[redmine_cmis_attachments] Getting object")
        begin
          self.repository.object(cmis_object_id)
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error obteniendo objeto. Causa: " + e.to_s)
          return nil
        end
      end

      def get_parent(cmis_object_id)
        begin
          self.repository.object(cmis_object_id).parent_id
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error obteniendo padre del objeto. Causa: " + e.to_s)
          return nil
        end
      end

      def subfolder_by_name(parent_folder, name)
        begin
          nameAux = name.gsub(/[\/\*\<\>\:\"\'\?\|\\]|[\. ]$/, '_')
          q = repository.query "SELECT * FROM cmis:folder WHERE IN_FOLDER('#{parent_folder.cmis_object_id}') and cmis:name='#{nameAux}'"
          if q.total > 0
            subfolder = q.results[0]
          else
            newfolder = repository.new_folder
            newfolder.name = nameAux
            newfolder.object_type_id = CMIS_FOLDER
            subfolder = parent_folder.create(newfolder)
          end
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] (subfolder_by_name) Error obteniendo/creando subcarpeta. Causa: " + e.to_s)
          return nil
        end
      end

      # Obtiene una carpeta con el nombre indicado que está bajo la raíz indicada
      def folder_by_tree_and_name(root, name)
        begin
          nameAux = name.gsub(/[\/\*\<\>\:\"\'\?\|\\]|[\. ]$/, '_')
          q = repository.query "SELECT * FROM cmis:folder WHERE IN_TREE('#{root}') and cmis:name='#{nameAux}'"
          if q.total > 0
            folder = q.results[0]
          end
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] (folder_by_tree_and_name) Error obteniendo/creando subcarpeta. Causa: " + e.to_s)
          return nil
        end
      end

      # Obtiene documentos dentro de una carpeta
      def get_documents_in_folder(cmis_object_id)
        Rails.logger.info("[redmine_cmis_attachments] Obteniendo documentos de carpeta #{cmis_object_id}")
        begin
          ret = []
          children = self.repository.object(cmis_object_id).children
          children.each_child(:limit => 1000) do |c|
            document_types = RedmineCmisAttachmentsSettings.document_types
            if document_types.key?(c.object_type_id) or document_types.key?(c.object_type_id.to_s.sub('D:', ''))
              ret.push(c)
            end
          end
          return ret
        rescue Exception => e
          Rails.logger.error('[redmine_cmis_attachments] Error obteniendo adjuntos. Causa: ' + e.to_s)
          return nil
        end
      end

      def get_cmis_name(cmis_object_id)
        begin
          self.repository.object(cmis_object_id).name
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error obteniendo cmis name del objeto. Causa: " + e.to_s)
          return nil
        end
      end
      
      #Metodo que se encarga de crear una carpeta o si ya existiera devolver el id
      #en los dos casos para poder continuar creando subcarpetas a partir de ella
      def my_create_folder(target_folder_cmis_object_id, name)
        begin
          nameAux = name.gsub(/[\/\*\<\>\:\"\'\?\|\\]|[\. ]$/, '_')
          target_folder = self.repository.object(target_folder_cmis_object_id)
          q = repository.query "SELECT * FROM cmis:folder WHERE IN_FOLDER('#{target_folder.cmis_object_id}') and cmis:name='#{nameAux}'"
          if q.total > 0
            subfolder = q.results[0]
          else
            newfolder = repository.new_folder
            newfolder.name = nameAux
            newfolder.object_type_id = CMIS_FOLDER
            subfolder = target_folder.create(newfolder)
          end
          return subfolder.cmis_object_id
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error creando carpeta. Causa: " + e.to_s)
          return nil
        end
      end

      def delete_folder(cmis_object_id, eventoIssue)
        Rails.logger.debug("[redmine_cmis_attachments] delete_folder cmis_object_id: #{cmis_object_id} eventoIssue: #{eventoIssue}.")
        begin
          if is_temp_folder(cmis_object_id)
            Rails.logger.error("[redmine_cmis_attachments] Se ha intentado eliminar la carpeta temporal.")
          elsif is_root_folder(cmis_object_id)
            Rails.logger.error("[redmine_cmis_attachments] Se ha intentado eliminar la carpeta raíz.")
          else
            q = repository.query "SELECT * FROM cmis:folder WHERE cmis:objectId='#{cmis_object_id}'"
            if q.total > 0
              result = q.results[0]
              if ((eventoIssue || result.children.total == 0) && is_project(result.cmis_object_id) == 'false')
                self.repository.object(result.cmis_object_id).delete
              end
            end
          end
        rescue CMIS::Exceptions::ObjectNotFound
          Rails.logger.error("[redmine_cmis_attachments] delete_folder Trying to erase inexistent object #{cmis_object_id}")
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error borrando carpeta. Causa: " + e.to_s)
        end
      end

      def delete_folder_by_name(nameFolder, eventoIssue)
        Rails.logger.debug("[redmine_cmis_attachments] delete_folder_by_name nameFolder: #{nameFolder} eventoIssue: #{eventoIssue}.")
        begin
          q = repository.query "SELECT * FROM cmis:folder WHERE cmis:name='#{nameFolder}'"
          if q.total > 0
            result = q.results[0]
            if (eventoIssue || result.children.total == 0)
              self.repository.object(result.cmis_object_id).delete
            end
          end
        rescue CMIS::Exceptions::ObjectNotFound
          Rails.logger.error("[redmine_cmis_attachments] delete_folder_by_name Trying to erase inexistent object #{nameFolder}")
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error borrando carpeta. Causa: " + e.to_s)
        end
      end

      #Obtiene un array de carpetas pertenecientes al archivo a borrar,
      # que se verificaran si son posibles de borrar
       def obtain_cmis_folders(cmis_object_id, foldersRoot)
        begin
          result = {}
          i = 0

          cmisObject = self.repository.object(cmis_object_id)
          father = cmisObject.parents[0]
          foundRootFolder = false

          while (father != nil && ((father.parents.nil? && father.parents.any?) || !foundRootFolder))
            for j in 0..foldersRoot.length
              if foldersRoot[j].eql?(father.name)
                foundRootFolder = true
              end
            end

            if (!foundRootFolder) 
              result[i] = father
              i = i + 1
              father = father.parents[0]
            end
          end
          return result
        rescue CMIS::Exceptions::ObjectNotFound
          Rails.logger.error("[redmine_cmis_attachments] Trying to erase inexistent object #{cmis_object_id}")
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error obteniendo carpetas a borrar. Causa: " + e.to_s)
        end
        return nil
      end

      def move(cmis_object_id, filename, target_folder_cmis_object_id, subfolder_name = nil, propertiesAux = nil, project_identifier = nil)
        Rails.logger.debug("[redmine_cmis_attachments] move #{cmis_object_id} to #{target_folder_cmis_object_id}")
        begin
          document = self.repository.object(last_version_of cmis_object_id)

          parent_folder = nil
          foldersFathers = nil
          if document.parents != nil && !document.parents.empty?
            parent_folder = document.parents[0]

            if parent_folder != nil
#              files_folder = I18n.t(:label_file_plural).upcase
#              issues_folder = I18n.t(:label_issue_plural).upcase
#              news_folder = I18n.t(:label_news_plural).upcase
#              documents_folder = I18n.t(:label_document_plural).upcase
#              wikis_folder = I18n.t(:label_wiki).upcase
#              messages_folder = I18n.t(:label_message_plural).upcase
#              foldersRoot = Array[files_folder,issues_folder,news_folder,documents_folder,wikis_folder,messages_folder]
              foldersRoot = Array.new
              root_folder_cmis_object_id = Setting.plugin_redmine_cmis_attachments["documents_path_base"]
              main_root = self.repository.object(root_folder_cmis_object_id)
              foldersRoot.push(main_root.name)
              foldersFathers = obtain_cmis_folders(document.cmis_object_id, foldersRoot)
            end
          end

          begin
            # Se terminan de actualizar los metadatos personalizados
            if propertiesAux != nil && !propertiesAux.empty?
              document.update_properties(propertiesAux)
            end
          rescue Exception => e
            Rails.logger.error("[redmine_cmis_attachments] Error actualizando metadatos del objeto. Causa: " + e.to_s)
          end

          target_folder = self.repository.object(target_folder_cmis_object_id)
          target_folder = subfolder_by_name(target_folder, subfolder_name) unless subfolder_name.nil?
          5.times do
            begin
              break if document.move target_folder
            rescue Exception => e
              #TODO: further check if it's a duplicate name exception
              Rails.logger.warn("[redmine_cmis_attachments] Exception captured in temp folder: #{e.message}")
              document = rename document.cmis_object_id, filename, true
            end
          end
          Rails.logger.debug("[redmine_cmis_attachments] Moved. Trying to rename object id #{document.cmis_object_id}")
          rename document.cmis_object_id, filename, false

          if foldersFathers != nil && !foldersFathers.empty?
            for i in 0..(foldersFathers.length-1)
              delete_folder(foldersFathers[i].cmis_object_id, false)
            end
          end
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error moviendo objeto. Causa: " + e.to_s)
          return nil
        end
      end

      def rename(cmis_object_id, filename, doRename)
        name = filename
        5.times do
          begin
            if doRename
              name = rename_file filename
            end
            document = self.repository.object(last_version_of cmis_object_id)
            document.update_properties('cmis:name'=>name)
            document = self.repository.object(last_version_of cmis_object_id)
            Rails.logger.debug("[redmine_cmis_attachments] Renamed #{document.cmis_object_id} to #{name}")
            return document
          rescue Exception => e
            Rails.logger.error("[redmine_cmis_attachments] Exception trying to rename #{e.message}")
            name = rename_file filename
          end
        end
        raise "[redmine_cmis_attachments] Unable to rename"
      end

      def last_version_of cmis_object_id        
        begin
          if self.repository.object(cmis_object_id).object_type != "cmis:folder"
            #self.repository.object(cmis_object_id).version_series_id
            cmis_object_id
          else
            cmis_object_id
          end
        rescue CMIS::Exceptions::ObjectNotFound
          cmis_object_id
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error obteniendo la última versión del objeto. Causa: " + e.to_s)
        end
      end

      def mkdir(parent_cmis_object_id, new_folder_name)        
        Rails.logger.debug("[redmine_cmis_attachments] Creating folder #{name}")
        begin
          parent_folder = repository.object(parent_cmis_object_id)
          newfolder = repository.new_folder
          newfolder.name = new_folder_name
          newfolder.object_type_id = CMIS_FOLDER
          cmis_object_id = parent_folder.create(newfolder).cmis_object_id
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error creando carpeta. Causa: " + e.to_s)
        end
      end

      def temp_folder
        begin
          temp_folder_cmis_object_id = Setting.plugin_redmine_cmis_attachments["temp_folder_cmis_object_id"]
          Rails.logger.debug("[redmine_cmis_attachments] Looking up temp folder #{temp_folder_cmis_object_id}")
          if temp_folder_cmis_object_id.blank?
            temp_folder_cmis_object_id = mkdir(Setting.plugin_redmine_cmis_attachments[:documents_path_base],"temp")
            Setting.plugin_redmine_cmis_attachments["temp_folder_cmis_object_id"]=temp_folder_cmis_object_id
            # TODO: Save it to the database!!
          end
          temp_folder_cmis_object_id
        rescue Exception => e
          Rails.logger.error("[redmine_cmis_attachments] Error creando carpeta temporal. Causa: " + e.to_s)
          return nil
        end
      end

      def thumb_folder
        Rails.logger.debug("[redmine_cmis_attachments] Looking up thumb folder")
        config = Setting.plugin_redmine_cmis_attachments
        self.repository.object config[:thumb_folder]
      end

      def content_type(cmis_object_id)
        Rails.logger.debug("[redmine_cmis_attachments] Returning content_type for #{cmis_object_id}")
        self.repository.object(cmis_object_id).content_type
      end

      def rename_file(filename)
        random = timestamp = nil
        nameChange = nil
        #random = "_#{Random.rand(1000000)}" if !timestamp.nil?
        #timestamp = "_#{DateTime.now.strftime("%Y-%m-%d-%H-%M-%S")}" if timestamp.nil?
        timestamp = "_#{DateTime.now.to_i.to_s}" if timestamp.nil?
        extn = File.extname  filename
        nameChange = "#{File.basename filename, extn}#{timestamp}#{extn}"
      end

      def is_temp_folder(cmis_object_id)
        temp_folder_cmis_object_id = Setting.plugin_redmine_cmis_attachments["temp_folder_cmis_object_id"]
        isTempFolder = false
        if !temp_folder_cmis_object_id.nil? && temp_folder_cmis_object_id != '' && temp_folder_cmis_object_id == cmis_object_id
          isTempFolder = true
        end
        return isTempFolder
      end

      def is_root_folder(cmis_object_id)
        root_folder_cmis_object_id = Setting.plugin_redmine_cmis_attachments["documents_path_base"]
        isRootFolder = false
        if !root_folder_cmis_object_id.nil? && root_folder_cmis_object_id != '' && root_folder_cmis_object_id == cmis_object_id
          isRootFolder = true
        end
        return isRootFolder
      end

      def is_project(cmis_object_id)
        resultado = RedmineCmisAttachmentsSettings.get_project_by_value_no_inherit("documents_path_base", cmis_object_id)
        if resultado.nil?
          return 'false'
        else
          return 'true'
        end
      end
    end
  end

end
