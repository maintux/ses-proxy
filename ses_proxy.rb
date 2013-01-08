module SesProxy
  ROOT = File.expand_path(File.join(File.dirname(__FILE__)))
  autoload :MainCommand, 'ses_proxy/main_command'
  autoload :SnsEndpoint, 'ses_proxy/sns_endpoint'
  autoload :SmtpServer, 'ses_proxy/smtp_server'
  autoload :Conf, 'ses_proxy/conf'
  autoload :Bounce, 'ses_proxy/models/bounce'
  autoload :Complaint, 'ses_proxy/models/complaint'
  autoload :Email, 'ses_proxy/models/email'
  autoload :BouncedEmail, 'ses_proxy/models/bounced_email'
  autoload :RecipientsNumber, 'ses_proxy/models/recipients_number'
end