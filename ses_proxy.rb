module SesProxy
  ROOT = File.expand_path(File.join(File.dirname(__FILE__)))
  autoload :MainCommand, 'ses_proxy/main_command'
  autoload :SnsEndpoint, 'ses_proxy/sns_endpoint'
  autoload :SmtpServer, 'ses_proxy/smtp_server'
  autoload :Conf, 'ses_proxy/conf'
end