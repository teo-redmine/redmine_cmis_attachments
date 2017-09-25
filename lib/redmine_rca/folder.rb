module RedmineRca
  class Folder
    def initialize(cmis_object_id)
      begin
        @repository = Connection.repository
        @cmis_object_id = cmis_object_id
        @cmis_object = @repository.object(cmis_object_id)
      rescue Exception => e
        Rails.logger.error('[redmine_cmis_attachments] Error inicializando carpeta. Causa: ' + e.to_s)
      end
    end

    def id
      @cmis_object_id
    end

    def subfolders
      begin
        ret = []
        q = @repository.query "SELECT * FROM cmis:folder WHERE IN_FOLDER('#{@cmis_object_id}')"
        q.each_result(:limit => 1000) do |r|
          ret << Folder.new(r.cmis_object_id)
        end
        ret
      rescue Exception => e
        Rails.logger.error('[redmine_cmis_attachments] Error obteniendo subcarpetas. Causa: ' + e.to_s)
        return nil
      end
    end

    def attachments
      begin
        ret = []
        #q = @repository.query "SELECT * FROM cmis:document WHERE IN_FOLDER('#{@cmis_object_id}')"

        queryStr1 = "SELECT * FROM cmis:document WHERE IN_FOLDER('#{@cmis_object_id}')"
        queryStr2 = nil

        document_type = Setting.plugin_redmine_cmis_attachments["document_type"]

        if document_type != nil && document_type != '' && document_type != 'cmis:document'
          queryStr2 = "SELECT * FROM " + document_type.to_s + " WHERE IN_FOLDER('#{@cmis_object_id}')"
        end

        q = @repository.query queryStr1
        q.each_result(:limit => 1000) do |r|
          #ret << Attachment.find_by_cmis_object_id(r.cmis_object_id)
          resultado = Attachment.find_by_cmis_object_id(r.cmis_object_id)
          if resultado != nil
            ret << resultado
          end
          Rails.logger.debug("[redmine_cmis_attachments] Returning attachment #{Attachment.find_by_cmis_object_id(r.cmis_object_id)} (tipo default: cmis:document)")
          Rails.logger.info('Elementos en alfresco: ' + q.total.to_s + ' Elementos en redmine: ' + ret.size.to_s + " (tipo default: cmis:document)")
        end

        if queryStr2 != nil
          q = @repository.query queryStr2
          q.each_result(:limit => 1000) do |r|
            resultado = Attachment.find_by_cmis_object_id(r.cmis_object_id)
            if resultado != nil
              ret << resultado
            end
            Rails.logger.debug("[redmine_cmis_attachments] Returning attachment #{Attachment.find_by_cmis_object_id(r.cmis_object_id)} (tipo: " + document_type.to_s + ")")
            Rails.logger.info('Elementos en alfresco: ' + q.total.to_s + ' Elementos en redmine: ' + ret.size.to_s + " (tipo: " + document_type.to_s + ")")
          end
        end

        ret.uniq
      rescue Exception => e
        Rails.logger.error('[redmine_cmis_attachments] Error obteniendo adjuntos. Causa: ' + e.to_s)
        return nil
      end
    end

    #stubs
    def title
      begin
        @cmis_object.name
      rescue Exception => e
        Rails.logger.error('[redmine_cmis_attachments] Error obteniendo título. Causa: ' + e.to_s)
        return nil
      end
    end

    def description
      begin
        @cmis_object.description
      rescue Exception => e
        Rails.logger.error('[redmine_cmis_attachments] Error obteniendo descripción. Causa: ' + e.to_s)
        return nil
      end
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

    def modified
      @cmis_object.last_modification_date
    end

    def user
      User.find_by(@cmis_object.created_by)
    end

    def notification
      false
    end

    def rcb_path
      []
    end

    def custom_field_values
      {}
    end

    def is_project
      resultado = redmine_project_id
      if resultado.nil?
        return false
      else
        return true
      end
    end

    def redmine_project_id
      return RedmineCmisAttachmentsSettings.get_project_by_value_no_inherit("documents_path_base", self.id)
    end

    def redmine_project_identifier
      if !redmine_project_id.nil?
        projectAux = Project.find(redmine_project_id)
        if !projectAux.nil? && !projectAux.identifier.nil?
          return projectAux.identifier
        end
      end
      return nil
    end
  end
end
