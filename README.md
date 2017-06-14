# CMIS Attachments plugin for Redmine

## Description

This [Redmine](http://www.redmine.org) plugin makes file attachments be stored on a CMIS repository using [cmis-ruby](https://github.com/UP-nxt/cmis-ruby) rather than on the local filesystem. This is a fork for [redmine_s3](https://github.com/ka8725/redmine_s3) using CMIS instead of an S3-compatible service.

## Requirements

CMIS API must implements CMIS 1.1 standard, we need Alfresco 5.0 or higher.


## Installation

1. Make sure Redmine is installed and cd into it's root directory

2. `git clone` this plugin into redmine/plugins/redmine_cmis_attachments

3. `bundle exec rake redmine:plugins:migrate NAME=redmine_cmis_attachments RAILS_ENV=production` for execute migrations

4. Make sure that files and folders permissions are correct

5. `bundle install --without development test` for installing this plugin dependencies (if you already did it, doing a `bundle install` again whould do no harm)

6. `rm -Rf plugins/redmine_cmis_attachments/.git`

7. Restart mongrel/upload to production/whatever

## Uninstall

1. `bundle exec rake redmine:plugins:migrate NAME=redmine_cmis_attachments VERSION=0 RAILS_ENV=production` to rollback migrations

2. Delete plugin folder redmine/plugins/redmine_cmis_attachments

3. Restart mongrel/upload to production/whatever


## Configuration

* Server URL: CMIS Browser Binding service URL. (e.g. http://localhost:8080/alfresco/api/-default-/public/cmis/versions/1.1/browser)

* Repository ID: ObjectID del repositorio raíz del usuario de conexión. (e.g. -default-)

* Base folder ID: root folder ObjectID. (e.g. fa2dae23-f544-49d4-abb1-651c57ecfa2a)

* User: CMIS service connection user. (e.g. admin)

* Password: CMIS service connection password. (e.g. admin)

* Temp Folder ID: temp folder ObjectID. (e.g. fa2dae23-f544-49d4-abb1-651c57ecfa2a)

* Content Model: CMIS content model for documents metadata. (e.g. teo:document)


## License

This plugin is released under the [MIT License](http://www.opensource.org/licenses/MIT).