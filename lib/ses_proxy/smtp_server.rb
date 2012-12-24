require 'eventmachine'
require 'mail'
require 'aws'

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
      domains = ses.identities.domains.map(&:identity)
      email_addresses = ses.identities.email_addresses.map(&:identity)
      identity = nil
      if email_addresses.include?(sender)
        identity = ses.identities[sender]
      elsif domains.include?(sender.split('@').last)
        identity = ses.identities[sender.split('@').last]
      end
      identity&&identity.verified?
      @sender = sender
    end

    def receive_recipient(recipient)
      true
    end

    def receive_data_chunk(data)
      @message = "#{@message}\n#{data.join("\n")}"
      true
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
      @ses || AWS::SimpleEmailService.new(SesProxy::Conf.get[:aws])
    end

    def receive_message
      return false unless verified
      #Check if recipient are blacklisted
      mail = Mail.read_from_string(message)
      #mail.to
      begin
        ses.send_raw_email(mail.to_s)
        true
      rescue Exception => e
        puts e.message
        false
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