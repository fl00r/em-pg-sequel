module EM::PG
  module Sequel
    class ConnectionPool
      attr_reader :available

      def initialize(opts, &blk)
        @available = []
        @pending = []
        @acquire_blk = blk

        @disconnected_class = opts[:disconnect_class]

        opts[:size].times do
          @available.push @acquire_blk.call
        end
      end

      def execute
        conn = acquire
        yield conn
      rescue => e
        puts e.inspect
        conn = @acquire_blk.call if @disconnected_class && @disconnected_class === e
        raise
      ensure
        release(conn)
      end

      def acquire
        f = Fiber.current
        if conn = @available.pop
          conn
        else
          @pending << f
          Fiber.yield
        end
      end

      def release(conn)
        if job = @pending.shift
          EM.next_tick{ job.resume conn }
        else
          @available << conn
        end
      end
    end
  end
end
