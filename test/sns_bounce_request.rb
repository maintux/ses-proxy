require 'net/http'
require './lib/ses_proxy/conf'

uri = URI('http://localhost:9292/')
req = Net::HTTP::Post.new(uri.path)
req.body = <<-BODY
{
  "notificationType": "Bounce",
  "bounce": {
    "bounceType":"Permanent",
    "bounceSubType": "General",
    "bouncedRecipients":[
      {
        "emailAddress":"recipient1@example.com",
        "diagnosticCode":"smtp; 5.1.0 - Unknown address error 550-'5.1.1 <recipient1@example.com>: Recipient address rejected: User unknown in virtual mailbox table' (delivery attempts: 0)"
      },
      {
        "emailAddress":"recipient2@example.com",
        "diagnosticCode":"smtp; 5.1.0 - Unknown address error 550-'#5.1.0 Address rejected recipient2@example.com' (delivery attempts: 0)"
      }
    ],
    "timestamp":"2012-05-25T14:59:38.237-07:00",
    "feedbackId":"00000137860315fd-869464a4-8680-4114-98d3-716fe35851f9-000000"
  },
  "mail":{
    "timestamp":"2012-05-25T14:59:38.237-07:00",
    "messageId":"00000137860315fd-34208509-5b74-41f3-95c5-22c1edc3c924-000000",
    "source":"email_1337983178237@amazon.com",
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