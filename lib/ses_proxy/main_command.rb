require 'rubygems'
require 'clamp'

module SesProxy

  class StartCommand < Clamp::Command

    option ["-p","--port"], "LOCAL_PORT", "Listen port", :default => 25025

    def execute
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