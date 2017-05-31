class RedmineCmissAttachmentsStateController < ApplicationController
  unloadable

  menu_item :redmine_cmis_attachments

  before_filter :find_project

  def user_pref_save
    RedmineCmisAttachmentsSettings::config_params.each do |param|
      RedmineCmisAttachmentsSettings::set_project_param_value(@project, param, params[param])
    end

    redirect_to :controller => 'projects', :action => 'settings', :id => @project, :tab => 'hgp_cmis'
  end

  private

  def find_project
    @project = Project.find(params[:id])
  end

  def check_project(entry)
    if !entry.nil? && entry.project != @project
      raise HgpCmisAccessError, l(:error_entry_project_does_not_match_current_project)
    end
  end

end
