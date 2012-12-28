require 'net/http'
require './lib/ses_proxy/conf'

uri = URI('http://localhost:9292/')
req = Net::HTTP::Post.new(uri.path)
req.body = <<-BODY
{
  "notificationType":"Complaint",
  "complaint":{
    "userAgent":"Comcast Feedback Loop (V0.01)",
    "complainedRecipients":[
      {
        "emailAddress":"recipient1@example.com"
      }
    ],
    "complaintFeedbackType":"abuse",
    "arrivalDate":"2009-12-03T04:24:21.000-05:00",
    "timestamp":"2012-05-25T14:59:38.623-07:00",
    "feedbackId":"000001378603177f-18c07c78-fa81-4a58-9dd1-fedc3cb8f49a-000000"
  },
  "mail":{
    "timestamp":"2012-05-25T14:59:38.623-07:00",
    "messageId":"000001378603177f-7a5433e7-8edb-42ae-af10-f0181f34d6ee-000000",
    "source":"email_1337983178623@amazon.com",
    "destination":[
      "recipient1@example.com",
      "recipient2@example.com",
      "recipient3@example.com",
      "recipient4@example.com"
    ]
  }
}
BODY
req.content_type = 'text/plain; charset=UTF-8'
req['x-amz-sns-message-type'] = "Notification"
req['x-amz-sns-message-id'] = "da41e39f-ea4d-435a-b922-c6aae3915ebe"
req['x-amz-sns-topic-arn'] = SesProxy::Conf.get[:test][:topic_arn]
req['x-amz-sns-subscription-arn'] = SesProxy::Conf.get[:test][:subscription_arn]

res = Net::HTTP.start(uri.hostname, uri.port) {|http|
  http.request(req)
}

puts res.body