require 'clamp'
require 'rack'
require 'eventmachine'
require 'thread'
require 'fileutils'
require 'mongoid'
require 'daemons'
require 'tmpdir'

require File.join SesProxy::ROOT, 'app', 'web_panel'

module SesProxy

  class StartCommand < Clamp::Command
    option ["-s","--smtp-port"], "SMTP_PORT", "SMTP listen port (default: \"1025\")"
    def default_smtp_port
      if SesProxy::Conf.get[:smtp] and SesProxy::Conf.get[:smtp][:port]
        SesProxy::Conf.get[:smtp][:port]
      else
        1025
      end
    end

    option ["-o","--smtp-host"], "SMTP_HOST", "SMTP host (default: \"0.0.0.0\")"
    def default_smtp_host
      if SesProxy::Conf.get[:smtp] and SesProxy::Conf.get[:smtp][:host]
        SesProxy::Conf.get[:smtp][:host]
      else
        "0.0.0.0"
      end
    end

    option ["-p","--http-port"], "HTTP_PORT", "HTTP listen port (default: \"9292\")"
    def default_http_port
      if SesProxy::Conf.get[:http] and SesProxy::Conf.get[:http][:port]
        SesProxy::Conf.get[:http][:port]
      else
        9292
      end
    end

    option ["-l","--http-address"], "HTTP_ADDRESS", "HTTP listen address (default: \"0.0.0.0\")"
    def default_http_address
      if SesProxy::Conf.get[:http] and SesProxy::Conf.get[:http][:host]
        SesProxy::Conf.get[:http][:host]
      else
        "0.0.0.0"
      end
    end

    option ["-e","--environment"], "ENVIRONMENT", "Environment", :default => "development"

    option ["-c","--config-file"], "CONFIG_FILE", "Configuration file", :default => "#{File.join(Dir.home,'.ses-proxy','ses-proxy.yml')}"
    option ["-m","--mongoid-config-file"], "MONGOID_CONFIG_FILE", "Mongoid configuration file", :default => "#{File.join(Dir.home,'.ses-proxy','mongoid.yml')}"

    option ["-d","--demonize"], :flag, "Demonize application", :default => false

    option ["--pid-dir"], "PID_DIR", "Pid Directory", :default => Dir.tmpdir

    @@env = "development"

    def execute
      check_for_config_file config_file
      check_for_mongoid_config_file mongoid_config_file

      @@env = environment
      Mongoid.load! mongoid_config_file, @@env
      if @@env.eql?"development"
        Mongoid.logger.level = Logger::DEBUG
        Mongo::Logger.logger.level = Logger::DEBUG
      else
        Mongoid.logger.level = Logger::INFO
        Mongo::Logger.logger.level = Logger::INFO
      end

      app = Rack::Builder.new do
        use Rack::Reloader, 0 if @@env.eql?"development"
        map "/sns_endpoint" do
          run SesProxy::SnsEndpoint.new
        end
        run Sinatra::Application
      end.to_app
      options = {:app=>app, :environment=>environment, :server=>"thin", :Port=>http_port, :Host=>http_address}
      server = Rack::Server.new options

      SesProxy::SmtpServer.parms = {:auth => :required}
      if demonize?
        options = {:app_name => "ses_proxy", :dir_mode=>:normal, :dir=>pid_dir, :multiple=>true}
        group = Daemons::ApplicationGroup.new('ses_proxy', options)
        options[:mode] = :proc
        options[:proc] = Proc.new { EM.run{ SesProxy::SmtpServer.start smtp_host, smtp_port } }
        pid = Daemons::PidFile.new pid_dir, "ses_proxy_smtp"
        @smtp = Daemons::Application.new(group, options, pid)
        options[:proc] = Proc.new { server.start }
        pid = Daemons::PidFile.new pid_dir, "ses_proxy_http"
        @http = Daemons::Application.new(group, options, pid)
        @smtp.start
        @http.start
      else
        EM.run do
          SesProxy::SmtpServer.start smtp_host, smtp_port
          server.start
          trap(:INT) {
            SesProxy::SmtpServer.stop
            EM.stop
          }
        end
      end
    end

    private

    def check_for_config_file(path)
      if path.eql? File.join(Dir.home,'.ses-proxy','ses-proxy.yml').to_s
        unless File.directory? File.join(Dir.home,'.ses-proxy')
          Dir.mkdir(File.join(Dir.home,'.ses-proxy'))
        end
        unless File.exists? path
          FileUtils.cp File.join(ROOT,"template","ses-proxy.yml").to_s, path
          puts "ATTENTION: Edit '#{path}' file with your data and then restart ses_proxy."
          exit
        end
      else
        unless File.exists? path
          raise ArgumentError, "Configuration file '#{path}' not found!"
        end
      end
    end

    def check_for_mongoid_config_file(path)
      if path.eql? File.join(Dir.home,'.ses-proxy','mongoid.yml').to_s
        unless File.directory? File.join(Dir.home,'.ses-proxy')
          Dir.mkdir(File.join(Dir.home,'.ses-proxy'))
        end
        unless File.exists? path
          FileUtils.cp File.join(ROOT,"template","mongoid.yml").to_s, path
          puts "ATTENTION: Edit '#{path}' file with your data and then restart ses_proxy."
          exit
        end
      else
        unless File.exists? path
          raise ArgumentError, "Configuration file '#{path}' not found!"
        end
      end
    end
  end

  class StopCommand < Clamp::Command
    option ["--pid-dir"], "PID_DIR", "Pid Directory", :default => Dir.tmpdir

    def execute
      options = {:app_name => "ses_proxy", :dir_mode=>:normal, :dir=>pid_dir, :multiple=>true}
      group = Daemons::ApplicationGroup.new('ses_proxy', options)
      group.setup
      group.applications.each do |application|
        application.stop
      end
    end
  end

  class MainCommand < Clamp::Command
    subcommand "start", "Start proxy", StartCommand
    subcommand "stop", "Stop proxy", StopCommand
  end

end