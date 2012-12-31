require 'net/http'
require './lib/ses_proxy/conf'

uri = URI('http://localhost:9292/')
req = Net::HTTP::Post.new(uri.path)
msg = %Q{{"notificationType":"Bounce","bounce":{"reportingMTA":"dns; a192-11.smtp-out.amazonses.com","bounceType":"Permanent","bouncedRecipients":[{"emailAddress":"recipient1@example.com","status":"5.0.0","diagnosticCode":"smtp; 5.1.0 - Unknown address error 550-'Requested action not taken: mailbox unavailable' (delivery attempts: 0)","action":"failed"}],"bounceSubType":"General","timestamp":"2012-12-29T14:56:01.000Z","feedbackId":"0000013be729794c-d792580c-51c7-11e2-8222-7deccfe1af64-000000"},"mail":{"timestamp":"2012-12-29T14:55:51.000Z","source":"no-reply@example.com","messageId":"0000013be729724c-90281fd0-8cac-42c4-9710-f20d04b14b86-000000","destination":["recipient1@example.com"]}}}
req.body = <<-BODY
{
  "Type" : "Notification",
  "MessageId" : "cc748646-68d6-467a-8970-35173aa51fd5",
  "TopicArn" : "#{SesProxy::Conf.get[:test][:topic_arn]}",
  "Message" : "#{msg.gsub('"','\"')}",
  "Timestamp" : "2012-12-29T15:11:21.353Z",
  "SignatureVersion" : "1",
  "Signature" : "",
  "SigningCertURL" : ""
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