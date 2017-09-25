# encoding: UTF-8

module RedmineCmisAttachmentsSettings

  class << self

    def server_login
      @sever_login
    end

    def server_login=(server_login)
      @server_login = server_login
    end

    def server_password=(server_password)
      @server_password = server_password
    end

    # Define los parámetros de configuración
    def config_params
      # TODO Poner este array en una variable
      types = ["server_url", 
        "repository_id",
        "documents_path_base", 
        "server_login", 
        "server_password", 
        "temp_folder_cmis_object_id"]
      return types
    end

    def document_types
      document_types = Hash.new
      document_types['cmis:document'] = 'cmis:document'
      document_types['teo:fichero'] = 'teo:fichero'
      return document_types
    end

    def get_project_param_row(project, param)
      # Busco el registro en base de datos

      aux = RedmineCmisAttachmentsProjectParam.where(project_id: project.id.to_s, param: param)
      if (aux.empty?)
        # Si no lo encuentro, busco la configuración del proyecto padre, si lo hay
        encontrado = RedmineCmisAttachmentsProjectParam.new
        encontrado.project_id = project.id
        encontrado.param = param
        if (project.parent_id != nil)
          aux = get_project_param_row(Project.find(project.parent_id), param)
          encontrado.value = aux.value
        else
          # Si no hay proyecto padre, me quedo con la configuración por defecto
          encontrado.value = Setting.plugin_redmine_cmis_attachments[param]
        end
        encontrado.save
      else
        encontrado = aux[0]
      end
      return encontrado
    end

    def get_project_param_value(project, param)
      return get_project_param_row(project, param).value
    end

    def get_project_param_value_no_inherit(project, param)
      aux = RedmineCmisAttachmentsProjectParam.where(project_id: project.id.to_s, param: param)
      if aux.empty?
        return nil
      else
        return aux[0].value
      end
    end

    def get_project_by_value_no_inherit(param, value)
      aux = RedmineCmisAttachmentsProjectParam.where(param: param, value: value)
      if aux.empty?
        return nil
      else
        return aux[0].project_id
      end
    end

    def set_project_param_value(project, param, value)
      res = get_project_param_row(project, param)
      res.value = value
      res.save
    end

    def get_project_params(project)
      params = {}
      config_params.each do |param|
        params[param] = get_project_param_value(project, param)
      end
      params['server_login'] = @server_login
      params['server_password'] = @server_password
      return params
    end

  end

end
