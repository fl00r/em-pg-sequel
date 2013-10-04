module EM::PG
  module Sequel
    class ConnectionPool
      attr_reader :available, :allocated, :max_size

      def initialize(opts, &blk)
        @available = []
        @allocated = {}
        @pending = []
        @acquire_blk = blk

        @disconnected_class = opts[:disconnect_class]

        @max_size = opts[:size]
        execute {}
      end

      def size
        @available.length + @allocated.length
      end

      def execute
        fiber = Fiber.current
        if conn = @allocated[fiber.object_id]
          skip_release = true
        else
          conn = acquire(fiber)
        end
        begin
          yield conn
        rescue => e
          if @disconnected_class && @disconnected_class === e
            db.disconnect_connection(conn) if conn
            @allocated.delete(fiber.object_id)
            skip_release = true
          end
          raise
        end
      ensure
        release(fiber) unless skip_release
      end

      def acquire(fiber)
        if conn = @available.pop
          @allocated[fiber.object_id] = conn
        else
          if size < max_size
            allocate_new_connection(fiber.object_id)
          else
            @pending << fiber
            Fiber.yield
          end
        end
      end

      def allocate_new_connection(fiber_id)
        @allocated[fiber_id] = true
        @allocated[fiber_id] = @acquire_blk.call
      rescue Exception => e
        @allocated.delete(fiber_id)
        raise e
      end

      def release(fiber)
        conn = @allocated.delete(fiber.object_id)
        if pending = @pending.shift
          @allocated[pending.object_id] = conn
          EM.next_tick { pending.resume conn}
        else
          @available << conn
        end
      end
    end
  end
end
