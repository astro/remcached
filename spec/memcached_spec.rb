$: << File.dirname(__FILE__) + '/../lib'
require 'remcached'

describe Memcached do
  def run(&block)
    EM.run do
      Memcached.servers = %w(127.0.0.2 localhost:11212 localhost localhost)

      @timer = EM::PeriodicTimer.new(0.01) do
        # at least localhost & localhost
        if Memcached.usable_clients.length >= 2
          @timer.cancel
          block.call
        end
      end

    end
  end
  def stop
    Memcached.servers = []
    EM.stop
  end


  context "when doing a simple operation" do
    it "should add a value" do
      run do
        Memcached.add(:key => 'Hello',
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
        Memcached.get(:key => 'Hello') do |result|
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
        Memcached.set(:key => 'Hello',
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
        Memcached.get(:key => 'Hello') do |result|
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
        Memcached.delete(:key => 'Hello') do |result|
          result.should be_kind_of(Memcached::Response)
          result[:status].should == Memcached::Errors::NO_ERROR
          stop
        end
      end
    end

    it "should not get a value" do
      run do
        Memcached.get(:key => 'Hello') do |result|
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
          Memcached.set(:key => 'counter',
                  :value => '0') do |result|
            stop
          end
        end
      end

      it "should count #{$n} times" do
        @counted = 0
        def count
          Memcached.get(:key => 'counter') do |result|
            result[:status].should == Memcached::Errors::NO_ERROR
            value = result[:value].to_i
            Memcached.set(:key => 'counter',
                    :value => (value + 1).to_s,
                    :cas => result[:cas]) do |result|
              if result[:status] == Memcached::Errors::KEY_EXISTS
                count # again
              else
                result[:status].should == Memcached::Errors::NO_ERROR
                @counted += 1
                stop if @counted >= $n
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
          Memcached.get(:key => 'counter') do |result|
            result[:status].should == Memcached::Errors::NO_ERROR
            result[:value].to_i.should == $n
            stop
          end
        end
      end
    end
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

  context "when manipulating multiple records at once" do
    before :all do
      @n = 10
    end

    def key(n)
      "test:item:#{n}"
    end

    it "should add some items" do
      run do
        items = []
        @n.times { |i|
          items << { :key => key(i),
                     :value => 'Foo',
                     :expiration => 20 } if i % 2 ==  0
        }
        Memcached.multi_add(items) { |responses|
          stop
          @n.times { |i|
            if i % 2 == 0 && (response_i = responses[key(i)])
              response_i[:status].should == Memcached::Errors::NO_ERROR
            end
          }
        }
      end
    end

    it "should get all items" do
      run do
        items = []
        @n.times { |i|
          items << { :key => key(i) }
        }
        Memcached.multi_get(items) { |responses|
          stop
          @n.times { |i|
            if i % 2 == 0
              responses.should have_key(key(i))
              responses[key(i)][:status].should == Memcached::Errors::NO_ERROR
              responses[key(i)][:value].should == 'Foo'
            else
              # either no response because request was quiet, or not
              # found in case of last response
              if (response_i = responses[key(i)])
                response_i[:status].should == Memcached::Errors::KEY_NOT_FOUND
              end
            end
          }
        }
      end
    end

    it "should delete all items" do
      run do
        items = []
        @n.times { |i|
          items << { :key => key(i) }
        }
        Memcached.multi_delete(items) { |responses|
          stop
          @n.times { |i|
            if i % 2 == 0
              # either no response because request was quiet, or ok in
              # case of last response
              if (response_i = responses[key(i)])
                response_i[:status].should == Memcached::Errors::NO_ERROR
              end
            else
              responses[key(i)][:status].should == Memcached::Errors::KEY_NOT_FOUND
            end
          }
        }
      end
    end

    context "when the multi operation is empty" do
      it "should return immediately" do
        @results = []
        @calls = 0
        Memcached.multi_add([]) { |responses|
          @results += responses
          @calls += 1
        }
        @results.should be_empty
        @calls.should == 1
      end
    end
  end

end
