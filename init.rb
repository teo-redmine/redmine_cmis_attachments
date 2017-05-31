require 'redmine_s3'

require_dependency 'redmine_s3_hooks'

Redmine::Plugin.register :redmine_cmis_attachments do
  name 'Redmine CMIS Attachments'
  author 'Junta de Andalucía - Guadaltel'
  description 'Plugin para utilizar repositorio CMIS de Alfresco'
  version '0.0.1'
  author_url "http://www.guadaltel.com"

  requires_redmine :version_or_higher => '3.0.0'

  settings  :partial => 'settings/redmine_cmis_attachments_settings',
            :default => {
              'server_url' => 'http://HOST:PORT/alfresco/api/-default-/public/cmis/versions/1.1/browser',
              'repository_id' => 'XXX-XXX-XXX-XXX',
              'documents_path_base' => 'workspace://SpacesStore/XXXX',
              'server_login' => 'XXX',
              'server_password' => 'XXX',
              #'proxy' => false,
              'temp_folder_cmis_object_id' => 'workspace://SpacesStore/XXXX',
              'document_type' => 'cmis:document'
            }
  menu :project_menu, :redmine_cmis_attachments, { :controller => "redmine_cmis_attachments", :action => "show" }, :caption => :menu_redmine_cmis_attachments, :before => :documents, :param => :id
 
# TODO depurar
  #project_module :redmine_cmis_attachments do
  #  permission :redmine_cmis_attachments_user_preferences, {:redmine_cmis_attachments_state => [:user_pref_save]}
  #end
end
