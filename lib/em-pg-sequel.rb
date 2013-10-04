require 'em-synchrony'
require 'em-synchrony/pg'
require 'sequel'
require 'em-pg-sequel/connection_pool'

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