require 'em-synchrony/pg'
require 'sequel'
require 'em-pg-sequel/connection_pool'

module EM::PG
  class ConnectionPool < ::Sequel::ConnectionPool
    DEFAULT_SIZE = 4
    attr_accessor :pool
    def initialize(db, opts = {})
      super
      size = opts[:max_connections] || DEFAULT_SIZE
      @pool = ::EM::PG::Sequel::ConnectionPool.new(size: size, disconnect_class: ::Sequel::DatabaseConnectionError) do
        make_new(DEFAULT_SERVER)
      end
    end

    def size
      @pool.available.size
    end

    def hold(server = nil, &blk)
      @pool.execute(&blk)
    end

    def disconnect(server = nil)
      @pool.available.each{ |conn| db.disconnect_connection(conn) }
      @pool.available.clear
    end
  end
end

PGconn = PG::EM::Client

require 'sequel/adapters/postgres'

# Sequel::Postgres::CONVERTED_EXCEPTIONS << ::EM::PG::Error