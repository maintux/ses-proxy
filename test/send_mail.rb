require 'mail'
require './lib/ses_proxy/conf'

def send_plain_to_from(to, from, subject, message)

  Mail.defaults do
    delivery_method :smtp, {
      :address => 'localhost',
      :port => '1025',
      :user_name => SesProxy::Conf.get[:smtp_auth][:user],
      :password => SesProxy::Conf.get[:smtp_auth][:password],
      :authentication => :plain,
      :enable_starttls_auto => true
    }
  end

  mail = Mail.new do
    from(from)
    to(to)
    subject(subject)
    body(message)
    headers({"X-Sender-System" => "SES Proxy Test"})
  end
  mail.deliver!

end

begin
  send_plain_to_from(SesProxy::Conf.get[:test][:to], SesProxy::Conf.get[:test][:from], "hello", "hello")
  puts "good"
rescue Exception => e
  puts "bad"
  puts e.message
end