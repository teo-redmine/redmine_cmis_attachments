RedmineApp::Application.routes.draw do
  get 'redmine_cmis_attachments_state_user_pref_save', to: 'redmine_cmis_attachments_state#user_pref_save'
  patch 'redmine_cmis_attachments_state_user_pref_save', to: 'redmine_cmis_attachments_state#user_pref_save'
  get 'redmine_cmis_attachments_login', to: 'redmine_cmis_attachments#login'
  post 'redmine_cmis_attachments_login', to: 'redmine_cmis_attachments#login'
end
