$: << File.dirname(__FILE__) + '/../lib'
require 'remcached'

describe Memcached::Client do

  def run(&block)
    EM.run do
      @cl = Memcached::Client.connect('localhost', &block)
    end
  end
  def stop
    @cl.close_connection
    EM.stop
  end


  context "when getting stats" do
    before :all do
      @stats = {}
      run do
        @cl.stats do |result|
          result[:status].should == Memcached::Errors::NO_ERROR
          if result[:key] != ''
            @stats[result[:key]] = result[:value]
          else
            stop
          end
        end
      end
    end

    it "should have received some keys" do
      @stats.should include(*%w(pid uptime time version curr_connections total_connections))
    end
  end
end
