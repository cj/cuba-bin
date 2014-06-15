require "cuba"
require "cuba/bin/daemon"

module Cuba::Bin
  unless defined? VERSION
    VERSION = '0.3.0'
  end

  extend self

  def server
    Daemon.new.run
  end

  def deploy
    if ENV['CUBA_BIN_DEPLOY_PATH']
      require ENV['CUBA_BIN_DEPLOY_PATH']
    else
      %w(config/deploy deploy).each do |file|
        path = Dir.pwd + "/#{file}.rb"

        if File.file? path
          break require path
        end
      end
    end

    if defined? Deploy
      Deploy.new.run
    end
  end

  def argv
    @args ||= begin
      ARGV.shift
      ARGV
    end

    @args.each_with_index do |arg, i|
      if arg[/\s/]
        @args[i] = "\"#{arg}\""
      else
        @args[i] = arg
      end
    end

    @args
  end
end
