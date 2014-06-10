require 'listen'

module Cuba
  module Bin
    class Daemon
      extensions = %w(
        builder coffee creole css slim erb erubis jbuilder
        slim mote haml html js less liquid mab markdown md mdown mediawiki mkd mw
        nokogiri radius rb rdoc rhtml ru
        sass scss str textile txt wiki yajl yml
        env.*
      ).sort

      DEFAULT_RELOAD_PATTERN      = %r(\.(?:builder #{extensions.join('|')})$)

      DEFAULT_FULL_RELOAD_PATTERN = /^Gemfile(?:\.lock)?$/

      # todo> make configurable
      IGNORE_PATTERNS             = [/\.direnv/, /\.sass-cache/, /^tmp/]

      attr_accessor :options, :puma_args
      attr_accessor :puma_pid

      def initialize(puma_args)
        @puma_args = puma_args
        # @options, @puma_args = options, puma_args
        @options = {}
        options[:pattern]       ||= DEFAULT_RELOAD_PATTERN
        options[:full]          ||= DEFAULT_FULL_RELOAD_PATTERN
        options[:force_polling] ||= false
        self
      end


      def log(msg)
        $stderr.puts msg
      end

      def start_puma
        ENV['RACK_ENV'] ||= 'development'

        envs     = {}
        env      = '.env'
        rack_env = "#{env}.#{ENV['RACK_ENV']}"

        if File.file? rack_env
          env = rack_env
        elsif !File.file? env
          env = false
        end

        if env
          File.foreach env do |line|
            key, value = line.split "="
            envs[key] = value.gsub('\n', '').strip
          end
        end

        @puma_pid = Kernel.spawn(envs, 'puma', *puma_args)
      end

      # TODO maybe consider doing like: http://puma.bogomips.org/SIGNALS.html
      def reload_everything
        log 'reloading everything'
        Process.kill(:QUIT, puma_pid)
        Process.wait(puma_pid)
        start_puma
      end

      def shutdown
        listener.stop
        Process.kill(:TERM, puma_pid)
        Process.wait(puma_pid)
        exit
      end

      # tell puma to gracefully shut down workers
      def graceful_restart
        log 'graceful restart'
        Process.kill(:SIGUSR2, puma_pid)
      end

      def handle_change(modified, added, removed)
        log "File change event detected: #{{modified: modified, added: added, removed: removed}.inspect}"
        if (modified + added + removed).index {|f| f =~ options[:full]}
          reload_everything
        else
          graceful_restart
        end
      end

      def listener
        @listener ||= begin
          x = Listen.to(Dir.pwd, :relative_paths=>true, :force_polling=> options[:force_polling]) do |modified, added, removed|
            handle_change(modified, added, removed)
          end

          x.only([ options[:pattern], options[:full] ])
          IGNORE_PATTERNS.map{|ptrn| x.ignore(ptrn) }
          x
        end
      end

      def run
        that = self
        Signal.trap("INT") { |signo| that.shutdown }
        Signal.trap("EXIT") { |signo| that.shutdown }
        listener.start
        start_puma

        # And now we just want to keep the thread alive--we're just waiting around to get interrupted at this point.
        sleep(99999) while true
      end
    end
  end
end
