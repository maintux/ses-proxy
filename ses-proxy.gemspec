Gem::Specification.new do |s|
  s.name        = 'ses-proxy'
  s.version     = '0.0.1'
  s.date        = '2012-12-21'
  s.summary     = "SMTP Proxy for Amazon Simple Email Service with bounce and complaints support"
  s.authors     = ["Massimo Maino"]
  s.email       = 'maintux@gmail.com'
  s.executables = ['ses-proxy']
  s.files       = Dir['ses_proxy.rb', 'lib/**/*', 'bin/*']
  s.homepage    = 'https://github.com/maintux/ses-proxy'
  s.has_rdoc    = false
  s.licenses    = 'MIT'
  s.add_dependency 'clamp'
  s.add_dependency 'json'
  s.add_dependency 'rack'
  s.add_dependency 'thin'
  s.add_dependency 'aws-sdk'
  s.add_dependency 'mail'
  s.add_dependency 'eventmachine'
  s.add_dependency 'mongo'
  s.add_dependency 'bson_ext'
end
