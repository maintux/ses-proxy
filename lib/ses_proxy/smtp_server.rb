require 'eventmachine'
require 'mail'
require 'aws-sdk'

if SesProxy::Conf.get[:aws][:ses] and SesProxy::Conf.get[:aws][:ses][:username] and SesProxy::Conf.get[:aws][:ses][:password]
  Mail.defaults do
    delivery_method :smtp, {
      :address => 'email-smtp.us-east-1.amazonaws.com',
      :port => 587,
      :user_name => SesProxy::Conf.get[:aws][:ses][:username],
      :password => SesProxy::Conf.get[:aws][:ses][:password],
      :authentication => :login,
      :enable_starttls_auto => true
    }
  end
end

module SesProxy
  class SmtpServer < EM::P::SmtpServer

    def get_server_domain
      @host || "mock.smtp.server.local"
    end

    def get_server_greeting
      "smtp ses greetings"
    end

    def receive_plain_auth(user, password)
      @verified = SesProxy::Conf.get[:smtp_auth][:user].eql?(user) and SesProxy::Conf.get[:smtp_auth][:password].eql?(password)
    end

    def receive_sender(sender)
      sender = sender.gsub(/[<>]/,'')
      @sender = sender
      domains = VerifiedSender.where({:type=>'domain'}).map(&:ses_identity)
      if domains.empty?
        _domains = ses.identities.domains
        _domains.each do |domain|
          next unless domain.verified?
          VerifiedSender.create({:ses_identity => domain.identity, :type => 'domain', :created_at => Time.now, :updated_at => Time.now})
          domains << domain.identity
        end
      end
      email_addresses = VerifiedSender.where({:type=>'email'}).map(&:ses_identity)
      if email_addresses.empty?
        _email_addresses = ses.identities.email_addresses
        _email_addresses.each do |email_address|
          next unless email_address.verified?
          VerifiedSender.create({:ses_identity => email_address.identity, :type => 'email', :created_at => Time.now, :updated_at => Time.now})
          email_addresses << email_address.identity
        end
      end
      ok = (email_addresses.include?(sender) or domains.include?(sender.split('@').last))
      puts "Invalid sender!" unless ok
      return ok
    end

    def receive_recipient(recipient)
      recipients << recipient.gsub(/[<>]/,'')
      true
    end

    def receive_data_chunk(data)
      @message = "#{@message}\n#{data.join("\n")}"
      true
    end

    def recipients
      @recipients ||= []
    end

    def sender
      @sender || ""
    end

    def message
      @message || ""
    end

    def verified
      @verified || false
    end

    def ses
      @ses ||= AWS::SimpleEmailService.new(SesProxy::Conf.get[:aws])
    end

    def receive_message
      return false unless verified
      mail = Mail.read_from_string(message + "\n") #https://github.com/mikel/mail/issues/612#issuecomment-35564404
      bounced = Bounce.where({:email=>{"$in"=>recipients}, :count=>{"$gte"=>2}, :retry_at=>{"$gte"=>Time.now}}).map(&:email)

      #Remove bounced addresses
      actual_recipients = mail.to_addrs - bounced
      actual_cc_addrs = mail.cc_addrs - bounced
      actual_bcc_addrs = recipients - (mail.to_addrs + mail.cc_addrs) - bounced

      #Remove blacklisted domains
      if SesProxy::Conf.get[:blacklisted_domains] and SesProxy::Conf.get[:blacklisted_domains].any?
        bld = SesProxy::Conf.get[:blacklisted_domains]
        _proc = proc {|address| address unless bld.include?(address.split('@').last)}
        actual_recipients.collect!(&_proc).compact!
        actual_cc_addrs.collect!(&_proc).compact!
        actual_bcc_addrs.collect!(&_proc).compact!
      end

      #Remove blacklisted regexp
      if SesProxy::Conf.get[:blacklisted_regexp] and SesProxy::Conf.get[:blacklisted_regexp].any?
        blr = SesProxy::Conf.get[:blacklisted_regexp]
        _proc = proc {|address| address unless blr.map{|regexp| Regexp.new(regexp).match(address)}.compact.any? }
        actual_recipients.collect!(&_proc).compact!
        actual_cc_addrs.collect!(&_proc).compact!
        actual_bcc_addrs.collect!(&_proc).compact!
      end

      original_number = recipients.size
      filtered_number = actual_recipients.size + actual_cc_addrs.size + actual_bcc_addrs.size
      record = RecipientsNumber.new({
        :original=>original_number,
        :filtered=>filtered_number,
        :created_at => Time.now,
        :updated_at => Time.now
      })
      record.save!
      if actual_recipients.any?
        mail.to = actual_recipients.uniq.join(",")
        mail.cc = actual_cc_addrs.uniq.join(",")
        mail.bcc = actual_bcc_addrs.uniq.join(",")
        mail['X-SES-Proxy'] = 'True'
        unless SesProxy::Conf.get[:collect_sent_mails].eql? false
          record = Email.new({
            :sender => sender,
            :recipients => actual_recipients.uniq.join(","),
            :subject => mail.subject,
            :body => mail.decode_body,
            :system => mail['X-Sender-System']||"Unknown",
            :created_at => Time.now,
            :updated_at => Time.now
          })
          record.save!
        end
        begin
          if SesProxy::Conf.get[:aws][:ses] and SesProxy::Conf.get[:aws][:ses][:username] and SesProxy::Conf.get[:aws][:ses][:password]
            mail.deliver!
          else
            ses.send_raw_email(mail.to_s)
          end
        rescue Exception => e
          print "Error! "
          puts e.message
          return false
        end
      else
        puts "No valid recipients! #{mail.to_addrs}"
      end
      if not original_number.eql? filtered_number
        unless SesProxy::Conf.get[:collect_bounced_mails].eql? false
          mail.to = (recipients&bounced).uniq.join(",")
          mail.cc = (mail.cc_addrs&bounced).uniq.join(",")
          mail.bcc = (mail.bcc_addrs&bounced).uniq.join(",")
          record = BouncedEmail.new({
            :sender => sender,
            :recipients => (recipients&bounced).uniq.join(","),
            :subject => mail.subject,
            :body => mail.decode_body,
            :system => mail['X-Sender-System']||"Unknown",
            :created_at => Time.now,
            :updated_at => Time.now
          })
          record.save!
        end
      end
      if actual_recipients.empty? and SesProxy::Conf.get[:raise_error_if_no_recipients].eql?(true)
        return [550, "Message rejected because of all recipients are bounced!"]
      else
        return true
      end
    end

    def receive_ehlo_domain(domain)
      @ehlo_domain = domain
      true
    end

    def self.start(host, port)
      trap(:QUIT) { stop }
      @host = host
      @server = EM.start_server host, port, self
    end

    def self.stop
      if @server
       EM.stop_server @server
       @server = nil
      end
    end

    def self.running?
      !!@server
    end

    # Allow EM::Protocols::SmtpServer#receive_message to return an Array so that cases other than succeed/fail can be handled.
    # If an Array is returned it is expected to have two elements, the response code and the message (e.g. [451, "Temp Failure"]).
    # Does not break backward compatibility.
    def process_data_line ln
      if ln == "."
        if @databuffer.length > 0
          receive_data_chunk @databuffer
          @databuffer.clear
        end


        succeeded = proc {
          send_data "250 Message accepted\r\n"
          reset_protocol_state
        }
        failed = proc {
          send_data "550 Message rejected\r\n"
          reset_protocol_state
        }

        d = receive_message

        if d.respond_to?(:set_deferred_status)
          d.callback(&succeeded)
          d.errback(&failed)
        elsif d.kind_of?(Array)
          send_data d.join(' ') + "\r\n"
          reset_protocol_state
        else
          (d ? succeeded : failed).call
        end

        @state.delete :data
      else
        # slice off leading . if any
        ln.slice!(0...1) if ln[0] == ?.
        @databuffer << ln
        if @databuffer.length > @@parms[:chunksize]
          receive_data_chunk @databuffer
          @databuffer.clear
        end
      end
    end

  end
end
