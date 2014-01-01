require 'em-pg-client'
require 'sequel'
require 'em-pg-sequel/connection_pool'

$VERBOSE.tap do |old_verbose|
  $VERBOSE = nil
  PGconn = PG::EM::Client
  $VERBOSE = old_verbose
end

require 'sequel/adapters/postgres'