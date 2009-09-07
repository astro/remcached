$: << File.dirname(__FILE__) + '/../lib'
require 'remcached'

describe Memcached::Server do

  def run
    EM.run do
      Memcached::Server.new('localhost') { yield }
    end
  end
  def stop
    EM.stop
  end


  it "should set a value" do
    run do
      Memcached.set(:key => 'Hello',
                    :value => 'World') do |*a|
        p a
        stop
      end
    end
  end
  it "should get a value" do
    run do
      Memcached.get(:key => 'Hello') do |result|
        result[:body].should == 'World'
        result[:cas].should != 'Hello'
        stop
      end
    end
  end

end
