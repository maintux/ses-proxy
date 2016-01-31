require 'rack/request'
require 'json'
require 'aws-sdk'
require 'net/http'
require 'base64'
require 'openssl'
require 'active_support/all'

module SesProxy
  class SnsEndpoint

    CERTS_URI = {
      "us-east-1" => "http://sns.us-east-1.amazonaws.com/SimpleNotificationService.pem",
      "us-west-1" => "http://sns.us-west-1.amazonaws.com/SimpleNotificationService.pem",
      "eu-west-1" => "http://sns.eu-west-1.amazonaws.com/SimpleNotificationService.pem",
      "ap-southeast-1" => "http://sns.ap-southeast-1.amazonaws.com/SimpleNotificationService.pem"
    }

    def call(env)
      req = Rack::Request.new(env)
      res = []

      if not req.post? or not check_message_type(env) or not check_topic(env)
        return make_error
      end

      json_string = req.body.read
      sns_obj = nil

      begin
        if json_string and not json_string.strip.eql?""
          sns_obj = JSON.parse json_string
        end
        if sns_obj
          unless check_message_signature(sns_obj)
            puts "Error in message signature"
            return make_error
          end
          if env["HTTP_X_AMZ_SNS_MESSAGE_TYPE"].eql?"Notification"
            message = JSON.parse sns_obj["Message"]
            unless message
              return make_error
            end
            if message["notificationType"].eql? "Bounce"
              message["bounce"]["bouncedRecipients"].each do |recipient|
                if record = Bounce.where(:email => recipient["emailAddress"]).first
                  record.count ||= 0
                  record.count += 1
                  if record.count >= 2
                    record.retry_at ||= Time.now
                    record.retry_at = record.retry_at.to_time + ((2 ** (record.count - 2)) * 7).days
                  end
                  record.updated_at = Time.now
                  record.save!
                else
                  record = Bounce.new({
                    :email => recipient["emailAddress"],
                    :type => message["bounce"]["bounceType"],
                    :desc => recipient["diagnosticCode"],
                    :count => 1,
                    :created_at => Time.now,
                    :updated_at => Time.now
                  })
                  record.save!
                end
              end
            elsif message["notificationType"].eql? "Complaint"
              message["complaint"]["complainedRecipients"].each do |recipient|
                if record = Complaint.where(:email => recipient["emailAddress"]).first
                  record.updated_at = Time.now
                  record.save!
                else
                  record = Complaint.new({
                    :email=>recipient["emailAddress"],
                    :type=>message["complaint"]["complaintFeedbackType"],
                    :created_at=>Time.now,
                    :updated_at=>Time.now
                  })
                  record.save!
                end
              end
            end
          elsif env["HTTP_X_AMZ_SNS_MESSAGE_TYPE"].eql?"SubscriptionConfirmation" and sns_obj["Type"].eql? "SubscriptionConfirmation"
            sns.confirm_subscription :topic_arn=>sns_obj["TopicArn"], :token=>sns_obj["Token"], :authenticate_on_unsubscribe=>"true"
          end
          [200, {'Content-Type' => 'text/html'}, res]
        else
          puts "SNS Object is nil"
          return make_error
        end
      rescue Exception => e
        print "Error! "
        puts e.message
        return make_error
      end
    end

    private

    def check_message_signature(sns_obj)
      if sns_obj["Type"].eql? "Notification"
        string = get_notification_canonical_string(sns_obj)
      else
        string = get_subscription_confirmation_canonical_string(sns_obj)
      end
      region = sns_obj["TopicArn"].split(":")[3]
      signature = sns_obj["Signature"]
      #openssl x509 -in CERT -pubkey -noout > pub_key
      pub_key = OpenSSL::X509::Certificate.new(File.read(get_cert(region))).public_key
      #base64 -i -d signature > plain_signature
      plain_signature = Base64.decode64(signature)
      #openssl dgst -sha1 -verify pub -signature sigraw MESS
      pub_key.verify(OpenSSL::Digest::SHA1.new, plain_signature, string)
    end

    def get_cert(region)
      unless File.exists? File.join("/","tmp","#{region}_sns_cert.pem")
        res = fetch CERTS_URI[region]
        puts res.inspect
        if res and not res.eql?""
          open(File.join("/","tmp","#{region}_sns_cert.pem"), "wb") do |file|
            file.write(res)
          end
        else
          raise Exception, "Unable to get SNS Certificate!"
        end
      end
      File.join("/","tmp","#{region}_sns_cert.pem")
    end

    def get_notification_canonical_string(sns_obj)
      string = "Message\n"
      string = "#{string}#{sns_obj["Message"]}\n"
      string = "#{string}MessageId\n"
      string = "#{string}#{sns_obj["MessageId"]}\n"
      if sns_obj["Subject"]
        string = "#{string}Subject\n"
        string = "#{string}#{sns_obj["Subject"]}\n"
      end
      string = "#{string}Timestamp\n"
      string = "#{string}#{sns_obj["Timestamp"]}\n"
      string = "#{string}TopicArn\n"
      string = "#{string}#{sns_obj["TopicArn"]}\n"
      string = "#{string}Type\n"
      string = "#{string}#{sns_obj["Type"]}\n"
      string.force_encoding("UTF-8")
    end

    def get_subscription_confirmation_canonical_string(sns_obj)
      string = "Message\n"
      string = "#{string}#{sns_obj["Message"]}\n"
      string = "#{string}MessageId\n"
      string = "#{string}#{sns_obj["MessageId"]}\n"
      string = "#{string}SubscribeURL\n"
      string = "#{string}#{sns_obj["SubscribeURL"]}\n"
      string = "#{string}Timestamp\n"
      string = "#{string}#{sns_obj["Timestamp"]}\n"
      string = "#{string}Token\n"
      string = "#{string}#{sns_obj["Token"]}\n"
      string = "#{string}TopicArn\n"
      string = "#{string}#{sns_obj["TopicArn"]}\n"
      string = "#{string}Type\n"
      string = "#{string}#{sns_obj["Type"]}\n"
      string.force_encoding("UTF-8")
    end

    def fetch(uri_str, limit = 10)
      raise Exception, 'too many HTTP redirects' if limit == 0

      response = Net::HTTP.get_response(URI(uri_str))

      case response
      when Net::HTTPSuccess then
        response.body
      when Net::HTTPRedirection then
        puts response.inspect
        location = response['location']
        url = URI.parse(location)
        location = "#{URI(uri_str).scheme}://#{URI(uri_str).host}#{location}" unless url.host
        warn "redirected to #{location}"
        fetch(location, limit - 1)
      else
        response.value
      end
    end

    def make_error
      [422, {'Content-Type' => 'text/html'}, ["Wrong request!"]]
    end

    def sns
      @sns ||= AWS::SNS::Client.new(SesProxy::Conf.get[:aws])
    end

    def check_topic(env)
      topic_arn = env["HTTP_X_AMZ_SNS_TOPIC_ARN"]
      allowed_topic_arns = SesProxy::Conf.get[:aws][:allowed_topic_arns]
      topic_arn && allowed_topic_arns.include?(topic_arn)
    end

    def check_message_type(env)
      message_type = env["HTTP_X_AMZ_SNS_MESSAGE_TYPE"]
      message_type && ["SubscriptionConfirmation","Notification","UnsubscribeConfirmation"].include?(message_type)
    end

  end
end