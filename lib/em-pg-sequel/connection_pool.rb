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

        if conn = @allocated[fiber.object_id]
          skip_release = true
        else
          conn = acquire(fiber)
        end

        begin
          yield conn

        rescue ::Sequel::DatabaseDisconnectError => e
          db.disconnect_connection(conn) if conn
          @allocated.delete(fiber.object_id)
          skip_release = true

          raise
        ensure
          release(fiber) unless skip_release
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

      CONNECTION_POOL_MAP[:em_synchrony] = self
    end
  end
end
