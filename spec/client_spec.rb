$: << File.dirname(__FILE__) + '/../lib'
require 'remcached'

describe Memcached::Client do

  def run(&block)
    EM.run do
      @cl = Memcached::Client.connect('localhost', &block)
    end
  end
  def stop
    EM.stop
  end


  it "should set a value" do
    run do
      @cl.set(:key => 'Hello',
              :value => 'World') do |result|
        result.should be_kind_of(Memcached::Response)
        result[:status].should == Memcached::Errors::NO_ERROR
        result[:cas].should_not == 0
        stop
      end
    end
  end
  it "should get a value" do
    run do
      @cl.get(:key => 'Hello') do |result|
        result[:value].should == 'World'
        result[:cas].should_not == 0
        stop
      end
    end
  end

end
