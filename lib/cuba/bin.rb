require "cuba"
require "cuba/bin/daemon"

module Cuba::Bin
  unless defined? VERSION
    VERSION = '0.2.2'
  end

  extend self

  def server
    Daemon.new(argv).run
  end

  private

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
