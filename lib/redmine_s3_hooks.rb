# This class hooks into Redmine's View Listeners in order to add content to the page
class RedmineS3Hooks < Redmine::Hook::ViewListener

  def view_layouts_base_html_head(context = {})
    javascript_include_tag 'redmine_s3.js', :plugin => 'redmine_cmis_attachments'
  end

  def add_projects_settings_tabs(context = {})
    if User.current.allowed_to?(:redmine_cmis_attachments_user_preferences, context[:project])
      context[:tabs].push({ :name => 'CMIS ALFRESCO',
                                 :action  => :new_tab_action,
                                 :partial => 'projects/settings/redmine_cmis_attachments_tab',
                                 :label   => :redmine_cmis_attachments })
    end
  end

  #TODO: subscribe to project_delete
end
