$: << File.dirname(__FILE__) + '/../lib'
require 'remcached'

describe Memcached::Client do
  def run(&block)
    EM.run do
      Memcached.servers = %w(127.0.0.2 localhost:11212 localhost localhost)

      started = false
      EM::PeriodicTimer.new(0.1) do
        if !started && Memcached.usable?
          started = true
          block.call
        end
      end

    end
  end
  def stop
    EM.stop
  end

  context "when using multiple servers" do
    it "should not return the same hash for the succeeding key" do
      run do
        Memcached.hash_key('0').should_not == Memcached.hash_key('1')
        stop
      end
    end

    it "should not return the same client for the succeeding key" do
      run do
        # wait for 2nd client to be connected
        EM::Timer.new(0.1) do
          Memcached.client_for_key('0').should_not == Memcached.client_for_key('1')
          stop
        end
      end
    end

    it "should spread load (observe from outside :-)" do
      run do

        n = 10000
        replies = 0
        n.times do |i|
          Memcached.set(:key => "#{i % 100}",
                        :value => rand(1 << 31).to_s) {
            replies += 1
            stop if replies >= n
          }
        end
      end

    end
  end

end
