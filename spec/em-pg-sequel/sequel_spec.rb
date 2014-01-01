require 'spec_helper'
require 'em-synchrony'
require 'em-synchrony/fiber_iterator'

describe EM::PG::Sequel do
  include SynchronyUtils

  DELAY = 1
  QUERY = "select pg_sleep(#{DELAY})"

  let(:url) { DB_URL }
  let(:size) { 1 }
  let(:db) { Sequel.connect(url, max_connections: size, pool_class: :em_synchrony, db_logger: Logger.new(nil)) }
  let(:test) { db[:test] }
  let(:fiber_iterator) { EM::Synchrony::FiberIterator }

  describe "sanity" do
    let(:size) { 42 }

    it "should have max_size 42" do
      db.pool.max_size.must_equal 42
    end

    it "should not release nil connection on connect error" do
      synchrony do
        db.disconnect
        db.pool.size.must_equal 0
        db.pool.stub :allocate_new_connection,
            proc { raise Sequel::DatabaseConnectionError } do

          proc { test.count }.must_raise Sequel::DatabaseConnectionError
          db.pool.size.must_equal 0
        end

      end
    end
  end

  describe "unexist table" do
    it "should raise exception" do
      synchrony do
        proc { test.all }.must_raise Sequel::DatabaseError

      end
    end
  end

  describe "exist table" do

    before do
      synchrony do
        db.create_table!(:test) do
          text :name
          integer :value, index: true
        end

      end
    end

    after do
      synchrony do
        db.drop_table?(:test)

      end
    end

    it "should connect and execute query" do
      synchrony do
        test.insert name: "andrew", value: 42
        test.where(name: "andrew").first[:value].must_equal 42

      end
    end


    describe "pool size is exceeded" do
      let(:size) { 1 }
      it "should queue requests" do
        synchrony do
          start = Time.now.to_f

          res = []
          fiber_iterator.new([1,2], 1).each do |t|
            res << db[QUERY].all
          end
          (Time.now.to_f - start.to_f).must_be_within_delta DELAY * 2, DELAY * 2 * 0.15
          res.size.must_equal 2

        end
      end
    end

    describe "pool size is enough" do
      let(:size) { 2 }
      it "should parallel requests" do
        synchrony do
          start = Time.now.to_f

          res = []
          fiber_iterator.new([1,2], 2).each do |t|
            res << db[QUERY].all
          end

          (Time.now.to_f - start.to_f).must_be_within_delta DELAY, DELAY * 0.30
          res.size.must_equal 2

        end
      end
    end

    describe "pool size is dynamic" do

      let(:size) { 2 }

      it "should have initial size of one" do
        db.pool.size.must_equal 1
      end

      it "should allocate second connection" do
        synchrony do
          res = []
          res << test.first
          db.pool.size.must_equal 1
          fiber_iterator.new([1,2], 2).each do |t|
            res << db[QUERY].all
          end
          db.pool.size.must_equal 2
          res.size.must_equal 3

        end
      end

      it "should not create more than size connections" do
        synchrony do
          db.pool.size.must_equal 1

          start = Time.now.to_f
          res = []
          fiber_iterator.new([1,1,2], 3).each do |pool_size|
            db.pool.size.must_equal pool_size
            res << db[QUERY].all
          end

          (Time.now.to_f - start.to_f).must_be_within_delta DELAY*2, DELAY * 2.60
          res.size.must_equal 3

          db.pool.size.must_equal size

        end
      end

      it "should clear all connections on disconnect" do
        synchrony do
          db.disconnect
          db.pool.size.must_equal 0
          res = []
          fiber_iterator.new([1,2,3], 3).each do |t|
            res << test.count
          end
          res.size.must_equal 3
          db.pool.size.must_equal size
          db.disconnect
          db.pool.size.must_equal 0

        end
      end

      it "should re-create 1st connection" do
        synchrony do
          db.disconnect
          db.pool.size.must_equal 0

          test.count.must_equal 0
          db.pool.size.must_equal 1

        end
      end

    end

    describe "on connection errors" do

      let(:size) { 3 }

      it "should not leave pending requests in queue" do
        synchrony do
          db.disconnect
          fiber_iterator.new((0..size), size).each { test.count }
          db.pool.available.each do |conn|
            # force clients to disconnected state
            conn.async_command_aborted = true
          end.length.must_equal db.pool.size

          db.pool.stub :make_new,
              proc {
                EM::Synchrony.sleep 0.1
                raise Sequel::DatabaseConnectionError } do

            request_counter = 0
            expected_runs = db.pool.max_size + 10
            expected_runs.times do |index|
              Fiber.new do

                pending = db.pool.instance_eval { @pending.length }
                pending.must_equal [index - db.pool.max_size, 0].max

                if index < db.pool.max_size
                  proc { test.count }.must_raise Sequel::DatabaseDisconnectError
                else
                  proc { test.count }.must_raise Sequel::DatabaseConnectionError
                end

                request_counter += 1

              end.resume
            end

            db.pool.instance_eval { @pending.length }.must_equal 10

            tick_sleep while request_counter < expected_runs

            db.pool.instance_eval { @pending.length }.must_equal 0
            db.pool.size.must_equal 0
            request_counter.must_equal expected_runs
          end

        end
      end
    end

    describe "play nice with transactions" do

      let(:size) { 2 }

      it "should lock connection to fiber" do
        synchrony do
          db.transaction do |conn|
            db.in_transaction?.must_equal true
            db.transaction do |inner_conn|
              inner_conn.must_be_same_as conn
              db.in_transaction?.must_equal true
            end
          end

        end
      end

      it "should allow separate transactions" do
        synchrony do
          db.transaction do |conn|
            db.in_transaction?.must_equal true
            fiber_iterator.new([1,2], 2).each do |t|
              db.in_transaction?.must_equal false
              db.transaction do |inner_conn|
                inner_conn.wont_be_same_as conn
                db.in_transaction?.must_equal true
              end
            end
          end

        end
      end
    end
  end
end