require 'redmine_rca/attachment_patch'
require 'redmine_rca/attachments_controller_patch'
require 'redmine_rca/application_helper_patch'
require 'redmine_rca/thumbnail_patch'
require 'redmine_rca/connection'
require 'redmine_rca/folder'

AttachmentsController.send(:include, RedmineRca::AttachmentsControllerPatch)
Attachment.send(:include, RedmineRca::AttachmentPatch)
ApplicationHelper.send(:include, RedmineRca::ApplicationHelperPatch)
Project.send(:include, RedmineRca::ProjectPatch)
Issue.send(:include, RedmineRca::IssuePatch)
WikiPage.send(:include, RedmineRca::WikiPagePatch)
Document.send(:include, RedmineRca::DocumentPatch)
DocumentCategory.send(:include, RedmineRca::DocumentCategoryPatch)
News.send(:include, RedmineRca::NewsPatch)
Version.send(:include, RedmineRca::VersionPatch)
