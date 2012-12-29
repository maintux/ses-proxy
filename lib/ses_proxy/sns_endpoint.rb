require 'rack/request'
require 'json'
require 'mongo'
require 'aws-sdk'

include Mongo

module SesProxy
  class SnsEndpoint

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
          message = JSON.parse sns_obj["Message"]
          unless message
            return make_error
          end
          if env["HTTP_X_AMZ_SNS_MESSAGE_TYPE"].eql?"Notification"
            if message["notificationType"].eql? "Bounce"
              coll = db['bounced']
              message["bounce"]["bouncedRecipients"].each do |recipient|
                coll.save({
                  :email=>recipient["emailAddress"],
                  :type=>message["bounce"]["bounceType"],
                  :desc=>recipient["diagnosticCode"],
                  :created_at=>Time.now,
                  :updated_at=>Time.now
                })
              end
            elsif message["notificationType"].eql? "Complaint"
              coll = db['complained']
              message["complaint"]["complainedRecipients"].each do |recipient|
                coll.save({
                  :email=>recipient["emailAddress"],
                  :type=>message["complaint"]["complaintFeedbackType"],
                  :created_at=>Time.now,
                  :updated_at=>Time.now
                })
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

    def make_error
      [422, {'Content-Type' => 'text/html'}, ["Wrong request!"]]
    end

    def sns
      @sns ||= AWS::SNS::Client.new(SesProxy::Conf.get[:aws])
    end

    def db
      @client ||= MongoClient.new(SesProxy::Conf.get[:db][:host], SesProxy::Conf.get[:db][:port])
      @db ||= @client[SesProxy::Conf.get[:db][:name]]
      return @db
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