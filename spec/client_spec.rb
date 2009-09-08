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


  it "should add a value" do
    run do
      @cl.add(:key => 'Hello',
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
        result.should be_kind_of(Memcached::Response)
        result[:status].should == Memcached::Errors::NO_ERROR
        result[:value].should == 'World'
        result[:cas].should_not == 0
        @old_cas = result[:cas]
        stop
      end
    end
  end

  it "should set a value" do
    run do
      @cl.set(:key => 'Hello',
              :value => 'Planet') do |result|
        result.should be_kind_of(Memcached::Response)
        result[:status].should == Memcached::Errors::NO_ERROR
        result[:cas].should_not == 0
        result[:cas].should_not == @old_cas
        stop
      end
    end
  end

  it "should get a value" do
    run do
      @cl.get(:key => 'Hello') do |result|
        result.should be_kind_of(Memcached::Response)
        result[:status].should == Memcached::Errors::NO_ERROR
        result[:value].should == 'Planet'
        result[:cas].should_not == @old_cas
        stop
      end
    end
  end

  it "should delete a value" do
    run do
      @cl.delete(:key => 'Hello') do |result|
        result.should be_kind_of(Memcached::Response)
        result[:status].should == Memcached::Errors::NO_ERROR
        stop
      end
    end
  end

  it "should not get a value" do
    run do
      @cl.get(:key => 'Hello') do |result|
        result.should be_kind_of(Memcached::Response)
        result[:status].should == Memcached::Errors::KEY_NOT_FOUND
        stop
      end
    end
  end

  $n = 100
  context "when incrementing a counter #{$n} times" do
    it "should initialize the counter" do
      run do
        @cl.set(:key => 'counter',
                :value => '0') do |result|
          stop
        end
      end
    end

    it "should count #{$n} times" do
      $counted = 0
      def count
        @cl.get(:key => 'counter') do |result|
          result[:status].should == Memcached::Errors::NO_ERROR
          value = result[:value].to_i
          @cl.set(:key => 'counter',
                  :value => (value + 1).to_s,
                  :cas => result[:cas]) do |result|
            if result[:status] == Memcached::Errors::KEY_EXISTS
              count # again
            else
              result[:status].should == Memcached::Errors::NO_ERROR
              $counted += 1
              stop if $counted >= $n
            end
          end
        end
      end
      run do
        $n.times { count }
      end
    end

    it "should have counted up to #{$n}" do
      run do
        @cl.get(:key => 'counter') do |result|
          result[:status].should == Memcached::Errors::NO_ERROR
          result[:value].to_i.should == $n
          stop
        end
      end
    end
  end
end
