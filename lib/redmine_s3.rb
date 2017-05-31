require 'redmine_s3/attachment_patch'
require 'redmine_s3/attachments_controller_patch'
require 'redmine_s3/application_helper_patch'
require 'redmine_s3/thumbnail_patch'
require 'redmine_s3/connection'
require 'redmine_s3/folder'

AttachmentsController.send(:include, RedmineS3::AttachmentsControllerPatch)
Attachment.send(:include, RedmineS3::AttachmentPatch)
ApplicationHelper.send(:include, RedmineS3::ApplicationHelperPatch)
Project.send(:include, RedmineS3::ProjectPatch)
Issue.send(:include, RedmineS3::IssuePatch)
WikiPage.send(:include, RedmineS3::WikiPagePatch)
Document.send(:include, RedmineS3::DocumentPatch)
News.send(:include, RedmineS3::NewsPatch)
Version.send(:include, RedmineS3::VersionPatch)
