module EM::PG
  module Sequel
    class ConnectionPool < ::Sequel::ConnectionPool

      DEFAULT_SIZE = 4

      attr_reader :available, :allocated, :max_size

      def initialize(db, opts = {})
        super
        @available = []
        @allocated = {}
        @pending = []

        @max_size = opts[:max_connections] || DEFAULT_SIZE
        hold {}
      end

      def size
        @available.length + @allocated.length
      end

      def hold(server = nil)
        fiber = Fiber.current
        fiber_id = fiber.object_id

        if conn = @allocated[fiber_id]
          skip_release = true
        else
          conn = acquire(fiber) until conn
        end

        begin
          yield conn

        rescue ::Sequel::DatabaseDisconnectError => e
          db.disconnect_connection(conn)
          drop_failed(fiber_id)
          skip_release = true

          raise
        ensure
          release(fiber_id) unless skip_release
        end
      end

      def disconnect(server = nil)
        @available.each{ |conn| db.disconnect_connection(conn) }
        @available.clear
      end

      private

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
        @allocated[fiber_id] = make_new(DEFAULT_SERVER)
      rescue Exception => e
        drop_failed(fiber_id)
        raise e
      end

      # drop failed connection (or a mark) from the pool and
      # ensure that the pending requests won't starve
      def drop_failed(fiber_id)
        @allocated.delete(fiber_id)
        if pending = @pending.shift
          EM.next_tick { pending.resume }
        end
      end

      def release(fiber_id)
        conn = @allocated.delete(fiber_id)
        if pending = @pending.shift
          @allocated[pending.object_id] = conn
          EM.next_tick { pending.resume conn}
        else
          @available << conn
        end
      end

      CONNECTION_POOL_MAP[:em_synchrony] = self
    end
  end
end
