module HasMailbox
  module Controllers
    module MethodHelpers
      extend ActiveSupport::Concern

      def self.define_methods(user_class_name,mapping = {})

        if mapping.empty?
          mapping[:user_object_name] = "current_user"
          mapping[:user_display_attribute] = "name"
        end

        class_eval <<-METHODS, __FILE__, __LINE__ + 1

        def index
          @mailbox = params[:mailbox].blank? ? "inbox" : params[:mailbox]
          @messages = #{mapping[:user_object_name]}.send(@mailbox).paginate(:page => params[:page], :per_page => 10)
        if @mailbox == "inbox"
            @options = ["Przeczytany","Nieprzeczytany","Skasuj"]
          elsif @mailbox == "outbox"
            @options = ["Skasuj"]
          elsif @mailbox == "trash"
            @mUndelete = I18n.t 'mUndelete'
            @options = ["Przyczytany","Nieprzeczytany","Skasuj",@mUndelete]
          end
        end

        def show
          unless params[:mailbox].blank?
            @message = #{mapping[:user_object_name]}.send(params[:mailbox]).find(params[:id])
            message_from = @message.from.#{mapping[:user_display_attribute]}
            message_created_at = @message.created_at.strftime('%A, %B %d, %Y at %I:%M %p')
          unless params[:mailbox] == "outbox"
              read_unread_messages(true,@message)
              @mNapisal = I18n.t 'mNapisal'
              @message_description = message_created_at +" <span class='recipient_name'>" + message_from + "</span> "+@mNapisal
              @user_tokens = @message.from.id
            else
              @mWyslales = I18n.t 'mWyslales'
              @message_description = @mWyslales + "<span class='recipient_name'>" + message_from + " </span>" + message_created_at + " :"
            end
          end
        end

        def new
        end

        def create
          unless params[:user_tokens].blank? or params[:subject].blank? or params[:body].blank?
            @mWyslano = I18n.t 'mWyslano'
            @recipients = #{user_class_name}.find(:first, :conditions => ["name = ?", params[:user_tokens]])
            if #{mapping[:user_object_name]}.send_message?(params[:subject],params[:body],@recipients)
              redirect_to mailboxes_url, :notice => @mWyslano
            else
              @mNiewyslano = I18n.t 'mNiewyslano'
              flash[:alert] = @mNiewyslano
              render :action => "new"
            end
          else
            @mPustepole = I18n.t 'mPustepole'
            flash[:alert] = @mPustepole
            render :action => "new"
          end  
        end

            def update
              unless params[:messages].nil?
                messages = #{mapping[:user_object_name]}.send(params[:mailbox]).find(params[:messages])
                  if params[:option].downcase == "read"
                    read_unread_messages(true,*messages)	
                  elsif params[:option].downcase == "unread"
                    read_unread_messages(false,*messages)
                  elsif params[:option].downcase == "delete"
                    delete_messages(true,*messages)
                  elsif params[:option].downcase == "undelete"
                    delete_messages(false,*messages)
                  end
                redirect_to box_mailboxes_url(params[:mailbox])
              else
                redirect_to box_mailboxes_url(params[:mailbox])
              end	
            end

            def token
              query = "%" + params[:q] + "%"
              recipients = #{user_class_name}.select("name,#{mapping[:user_display_attribute]}").where("#{mapping[:user_display_attribute]} like ?", query)
                respond_to do |format|
                format.json { render :json => recipients.map { |u| { "id" => u.id, "name" => u.#{mapping[:user_display_attribute]}} } }
                end
            end

            def read_unread_messages(isRead, *messages)
              messages.each do |msg|
                if isRead
                  msg.mark_as_read unless msg.read?
                else
                  msg.mark_as_unread if msg.read?
                end	
              end
            end

            def delete_messages(isDelete, *messages)
              messages.each do |msg|
                if isDelete
                  msg.delete	
                else
                  msg.undelete	
                end	
              end
            end

            METHODS

      end

    end	
  end
end
