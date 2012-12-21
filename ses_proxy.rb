module SesProxy
  ROOT = File.expand_path(File.join(File.dirname(__FILE__)))
  autoload :MainCommand, 'ses_proxy/main_command'
end