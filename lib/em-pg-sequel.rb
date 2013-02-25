require 'em-synchrony'
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

module PG::EM
  class SyncClient < Client
    # Dirty hack
    # To avoid patching ruby-em-pg-client and to support Sequel API
    # we should execute async_client asynchronously for em-pg and synchronously for sequel
    def async_exec(*args)
      if block_given?
        super
      else
        exec(*args)
      end
    end
  end
end

$VERBOSE.tap do |old_verbose|
  $VERBOSE = nil
  PGconn = PG::EM::SyncClient
  $VERBOSE = old_verbose
end

require 'sequel/adapters/postgres'