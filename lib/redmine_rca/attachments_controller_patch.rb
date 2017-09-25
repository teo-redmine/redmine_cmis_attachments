module RedmineRca
  module AttachmentsControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        before_filter :find_attachment_rca, :only => [:show]
        before_filter :download_attachment_rca, :only => [:download]
        before_filter :find_thumbnail_attachment_rca, :only => [:thumbnail]
        #before_filter :find_editable_attachments_rca, :only => [:edit, :update]
        skip_before_filter :file_readable
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def check_connection
        cmis_connection = RedmineRca::Connection.establish_connection
        if cmis_connection.nil?
          flash[:error] = I18n.t('msg_connection_error', default: '***Connection Error***')
          return false
        end
        return true
      end

      def find_attachment_rca
        if @attachment.is_diff?
          @diff = RedmineRca::Connection.get(@attachment.disk_filename)
          @diff_type = params[:type] || User.current.pref[:diff_type] || 'inline'
          @diff_type = 'inline' unless %w(inline sbs).include?(@diff_type)
          # Save diff type as user preference
          if User.current.logged? && @diff_type != User.current.pref[:diff_type]
            User.current.pref[:diff_type] = @diff_type
            User.current.preference.save
          end
          render :action => 'diff'
        elsif @attachment.is_text? && @attachment.filesize <= Setting.file_max_size_displayed.to_i.kilobyte
          @content = RedmineRca::Connection.get(@attachment.disk_filename)
          render :action => 'file'
        else
          download_attachment_rca
        end
      end

      def download_attachment_rca
        if !check_connection
          redirect_to :back
        else
          if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
            @attachment.increment_download
          end
          if RedmineRca::Connection.proxy?
            send_data RedmineRca::Connection.get(@attachment.disk_filename),
                                            :filename => filename_for_content_disposition(@attachment.filename),
                                            :type => detect_content_type(@attachment),
                                            :disposition => (@attachment.image? ? 'inline' : 'attachment')
          else
            redirect_to(RedmineRca::Connection.object_url(@attachment.disk_filename))
          end
        end
      end

      def find_editable_attachments_rca
        if @attachments
          @attachments.each { |a| a.increment_download }
        end
        if RedmineRca::Connection.proxy?
          @attachments.each do |attachment|
            send_data RedmineRca::Connection.get(attachment.disk_filename),
                                            :filename => filename_for_content_disposition(attachment.filename),
                                            :type => detect_content_type(attachment),
                                            :disposition => (attachment.image? ? 'inline' : 'attachment')
          end
        end
      end

      def find_thumbnail_attachment_rca
        update_thumb = 'true' == params[:update_thumb]
        url          = @attachment.thumbnail_rca(update_thumb: update_thumb)
        return render json: {src: url} if update_thumb
        return if url.nil?
        if RedmineRca::Connection.proxy?
          send_data RedmineRca::Connection.get(url, ''),
                    :filename => filename_for_content_disposition(@attachment.filename),
                    :type => detect_content_type(@attachment),
                    :disposition => (@attachment.image? ? 'inline' : 'attachment')
        else
          redirect_to(url)
        end
      end
    end
  end
end
