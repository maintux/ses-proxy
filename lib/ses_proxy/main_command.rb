
require 'clamp'
require 'rack'
require 'eventmachine'
require 'thread'
require 'fileutils'

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
    def default_http_host
      if SesProxy::Conf.get[:http] and SesProxy::Conf.get[:http][:host]
        SesProxy::Conf.get[:http][:host]
      else
        "0.0.0.0"
      end
    end

    option ["-e","--environment"], "ENVIRONMENT", "Environment", :default => "development"

    option ["-c","--config-file"], "CONFIG_FILE_PATH", "Configuration file", :default => "#{File.join(Dir.home,'.ses-proxy','ses-proxy.yml')}"

    @@env = "development"

    def execute
      check_for_config_file config_file_path

      @@env = environment

      smtp = Thread.new do
        EM.run{ SesProxy::SmtpServer.start smtp_host, smtp_port }
      end

      http = Thread.new do
        app = Rack::Builder.new do
          use Rack::Reloader, 0 if  @@env.eql?"development"
          run SesProxy::SnsEndpoint.new
        end.to_app
        server = Rack::Server.new :app=>app, :environment=>environment, :server=>"thin", :Port=>http_port, :Host=>http_address
        server.start
      end

      smtp.join
      http.join

      #mr = Rack::MockRequest.new app
      #puts mr.post("/").body
    end

    private

    def check_for_config_file(path)
      if path.eql? File.join(Dir.home,'.ses-proxy','ses-proxy.yml').to_s
        unless File.directory? File.join(Dir.home,'.ses-proxy')
          Dir.mkdir(File.join(Dir.home,'.ses-proxy'))
        end
        unless File.exists? path
          Fileutils.cp File.join(ROOT,"template","ses-proxy.yml").to_s, path
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

    def execute
    end

  end

  class MainCommand < Clamp::Command
    subcommand "start", "Start proxy", StartCommand
    subcommand "stop", "Stop proxy", StopCommand
  end

end