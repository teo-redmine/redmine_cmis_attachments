require 'redmine_rca'

Redmine::Plugin.register :redmine_cmis_attachments do
  name 'Redmine CMIS Attachments'
  author 'Junta de Andalucía - Guadaltel'
  description 'Plugin para utilizar repositorio CMIS de Alfresco'
  version '1.0.0'
  url 'https://github.com/teo-redmine/redmine_cmis_attachments.git'
  author_url "http://www.guadaltel.com"

  requires_redmine :version_or_higher => '3.0.0'

  settings  :partial => 'settings/redmine_cmis_attachments_settings',
            :default => {
              'server_url' => 'http://HOST:PORT/alfresco/api/-default-/public/cmis/versions/1.1/browser',
              'repository_id' => '-default-',
              'documents_path_base' => 'XXX-XXX-XXX-XXX',
              'server_login' => 'XXX',
              'server_password' => 'XXX',
              'temp_folder_cmis_object_id' => 'XXX-XXX-XXX-XXX',
              'document_type' => 'cmis:document'
            }
  menu :project_menu, :redmine_cmis_attachments, { :controller => "redmine_cmis_attachments", :action => "show" }, :caption => :menu_redmine_cmis_attachments, :before => :documents, :param => :id
end
