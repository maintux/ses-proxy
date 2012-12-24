require 'rack/request'
require 'rack/response'
require 'json'

module SesProxy
  class SnsEndpoint
    def call(env)
      req = Rack::Request.new(env)
      res = Rack::Response.new
      params = req.params
      json_string = req.body
      sns_obj = nil
      #if json_string and not json_string.strip.eql?""
      #  sns_obj = JSON.parse json_string
      #end
      #if sns_obj
      #  res.write "#{req.body.string.to_s}\n"
      #else
        res.write confirm_subscription("pippo","pluto")
      #end
      res.finish
      #return [200, {}, ["Hello world! #{req.GET.inspect}"]]
    end

    def sns
      @sns || AWS::SNS::Client.new(SesProxy::Conf.get[:aws])
    end

    def confirm_subscription(arn,token)
      sns.confirm_subscription :topic_arn=>arn, :token=>token, :authenticate_on_unsubscribe=>"true"
    end
  end
end