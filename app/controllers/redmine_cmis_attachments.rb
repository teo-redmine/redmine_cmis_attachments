class RedmineCmisAttachmentsController < ApplicationController
  include RedmineCmisAttachmentsModule

  unloadable

  before_filter :find_project
  before_filter :except => [:delete_entries]
  before_filter :find_folder, :except => [:new, :create, :edit_root, :save_root]
  before_filter :find_parent, :only => [:new, :create]

  def show
    if session[:cmis_server_login].blank?
      redirect_to :action => "login", :id => @project
      return
    else
      # Si los datos de autenticación están en sesión, me aseguro de ponerlos en el helper de project_settings
      RedmineCmisAttachmentsSettings::server_login = session[:cmis_server_login]
      RedmineCmisAttachmentsSettings::server_password = session[:cmis_server_password]
    end
    begin
      cmis_connect(RedmineCmisAttachmentsSettings::get_project_params(@project))

      if @folder.nil?
        @subfolders = folders_in_path("/")
        @files = files_in_path("/")
      else
        @subfolders = folders_in_path(@folder.path)
        @files = files_in_path(@folder.path)
      end

      @files.sort! do |a,b|
        a.last_revision.title <=> b.last_revision.title
      end
      flash.discard
    rescue HgpCmisException=>e
      flash[:error] = l(:error_conexion_hgp_cmis)
      flash.keep # Para no perder el mensaje de error
      redirect_to :action => "login", :id => @project
    end
  end
end
