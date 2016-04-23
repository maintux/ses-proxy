Gem::Specification.new do |s|
  s.name        = 'ses-proxy'
  s.version     = '0.3.3'
  s.date        = '2012-12-21'
  s.summary     = "SMTP Proxy for Amazon Simple Email Service with bounce and complaints support"
  s.authors     = ["Massimo Maino"]
  s.email       = 'maintux@gmail.com'
  s.executables = ['ses_proxy']
  s.files       = Dir['ses_proxy.rb', 'lib/**/*', 'bin/*', 'app/**/*', 'template/*']
  s.homepage    = 'https://github.com/maintux/ses-proxy'
  s.has_rdoc    = false
  s.licenses    = 'MIT'
  s.add_runtime_dependency 'clamp'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'rack'
  s.add_runtime_dependency 'thin'
  s.add_runtime_dependency 'aws-sdk-v1'
  s.add_runtime_dependency 'mail'
  s.add_runtime_dependency 'eventmachine'
  s.add_runtime_dependency 'mongoid'
  s.add_runtime_dependency 'haml'
  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'kaminari'
  s.add_runtime_dependency 'padrino-helpers'
  s.add_runtime_dependency 'daemons'
  s.add_runtime_dependency 'actionpack', '3.2.16'
end