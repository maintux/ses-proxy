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
  s.licenses    = 'GPL-2'
  s.add_dependency 'clamp'
end
