require 'eventmachine'
require 'mail'
require 'aws-sdk'

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
      domains = ses.identities.domains.map(&:identity)
      email_addresses = ses.identities.email_addresses.map(&:identity)
      identity = nil
      if email_addresses.include?(sender)
        identity = ses.identities[sender]
      elsif domains.include?(sender.split('@').last)
        identity = ses.identities[sender.split('@').last]
      end
      identity&&identity.verified?
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
      bounced = Bounce.where({:email=>{"$in"=>recipients}}).map(&:email)
      mail = Mail.read_from_string(message)
      #TODO: Define policy for retry when bounce is not permanent
      actual_recipients = recipients - bounced
      actual_cc_addrs = mail.cc_addrs - bounced
      actual_bcc_addrs = mail.bcc_addrs - bounced
      if actual_recipients.any?
        mail.to = actual_recipients.uniq.join(",")
        mail.cc = actual_cc_addrs.uniq.join(",")
        mail.bcc = actual_bcc_addrs.uniq.join(",")
        record = Email.new({
          :sender => sender,
          :recipients => actual_recipients.uniq.join(","),
          :subject => mail.subject,
          :body => mail.body.decoded,
          :system => mail['X-Sender-System']||"Unknown",
          :created_at => Time.now,
          :updated_at => Time.now
        })
        record.save!
        begin
          ses.send_raw_email(mail.to_s)
          true
        rescue Exception => e
          print "Error! "
          puts e.message
          false
        end
      else
        puts "No valid recipients!"
        true
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
  end
end