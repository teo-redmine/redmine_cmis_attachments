# S3 plugin for Redmine

## Description
This [Redmine](http://www.redmine.org) plugin makes file attachments be stored on a CMIS repository using [cmis-ruby](https://github.com/UP-nxt/cmis-ruby) rather than on the local filesystem. This is a fork for [redmine_s3](https://github.com/ka8725/redmine_s3) using CMIS instead of an S3-compatible service.

## Installation
1. Make sure Redmine is installed and cd into it's root directory
2. `git clone` this plugin
3. `bundle install --without development test` for installing this plugin dependencies (if you already did it, doing a `bundle install` again whould do no harm)
4. Restart mongrel/upload to production/whatever
5. *Optional*: Run `rake redmine_s3:files_to_s3` to upload files in your files folder to s3
6. `rm -Rf plugins/redmine_cmis_attachments/.git`

## License

This plugin is released under the [MIT License](http://www.opensource.org/licenses/MIT).
