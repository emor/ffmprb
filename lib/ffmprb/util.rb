require 'open3'

module Ffmprb

  module Util

    class Reader < Thread

      def initialize(input, store=false, log=nil)
        @output = ''
        @queue = Queue.new
        super do
          begin
            while s = input.gets
              Ffmprb.logger.debug log + s.chomp  if log
              @output << s  if store
            end
            @queue.enq @output
          rescue => e
            @queue.enq e
          end
        end
      end

      def read
        case res = @queue.deq
        when Exception
          raise res
        when ''
          nil
        else
          res
        end
      end

    end

    class << self

      def ffprobe(args)
        sh "ffprobe#{args}"
      end

      def ffmpeg(args)
        args = " -loglevel debug #{args}"  if Ffmprb.debug
        sh "ffmpeg -y#{args}"
      end

      def sh(cmd, output: :stdout, log: :stderr)
        Ffmprb.logger.info cmd
        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          stdin.close

          # XXX process timeouting/cleanup here will be appreciated

          begin
            log_cmd = "#{cmd.split(' ').first.upcase}: "  if log
            stdout_r = Reader.new(stdout, output == :stdout, log == :stdout && log_cmd)
            stderr_r = Reader.new(stderr, true, log == :stderr && log_cmd)

            raise Error.new "#{cmd}:\n#{stderr_r.read}"  unless
              wait_thr.value.exitstatus == 0  # NOTE blocks

            # NOTE only one of them will return non-nil, see above
            stdout_r.read || stderr_r.read
          ensure
            begin
              stdout_r.join  if stdout_r
              stderr_r.join  if stderr_r
            rescue => e
              Ffmprb.logger.error "Thread joining error: #{e.message}"
            end
          end
        end
      end

    end

  end

end