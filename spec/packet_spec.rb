$: << File.dirname(__FILE__) + '/../lib'
require 'remcached'

describe Memcached::Packet do

  context "when generating a request" do
    it "should set default values" do
      pkt = Memcached::Request.new
      pkt[:magic].should == 0x80
    end

    context "example 4.2.1" do
      before :all do
        pkt = Memcached::Request.new(:key => 'Hello')
        @s = pkt.to_s
      end

      it "should serialize correctly" do
        @s.should == ("\x80\x00\x00\x05" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x05" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "Hello").force_encoding("ASCII-8BIT")
      end
    end

    context "example 4.3.1 (add)" do
      before :all do
        pkt = Memcached::Request::Add.new(:flags => 0xdeadbeef,
                                          :expiration => 0xe10,
                                          :key => "Hello",
                                          :value => "World")
        @s = pkt.to_s
      end

      it "should serialize correctly" do
        @s.should == ("\x80\x02\x00\x05" +
          "\x08\x00\x00\x00" +
          "\x00\x00\x00\x12" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "\xde\xad\xbe\xef" +
          "\x00\x00\x0e\x10" +
          "Hello" +
          "World").force_encoding("ASCII-8BIT")
      end
    end
  end

  context "when parsing a response" do
    context "example 4.1.1" do
      before :all do
        s = ("\x81\x00\x00\x00\x00\x00\x00\x01" +
          "\x00\x00\x00\x09\x00\x00\x00\x00" +
          "\x00\x00\x00\x00\x00\x00\x00\x00" +
          "Not found").force_encoding("ASCII-8BIT")
        @pkt = Memcached::Response.parse_header(s[0..23])
        @pkt.parse_body(s[24..-1])
      end

      it "should return the right class according to magic & opcode" do
        @pkt[:magic].should == 0x81
        @pkt[:opcode].should == 0
        @pkt.class.should == Memcached::Response
      end
      it "should return the right data type" do
        @pkt[:data_type].should == 0
      end
      it "should return the right status" do
        @pkt[:status].should == Memcached::Errors::KEY_NOT_FOUND
      end
      it "should return the right opaque" do
        @pkt[:opaque].should == 0
      end
      it "should return the right CAS" do
        @pkt[:cas].should == 0
      end
      it "should parse the body correctly" do
        @pkt[:extras].should be_empty
        @pkt[:key].should == ""
        @pkt[:value].should == "Not found"
      end
    end

    context "example 4.2.1" do
      before :all do
        s =  ("\x81\x00\x00\x00" +
          "\x04\x00\x00\x00" +
          "\x00\x00\x00\x09" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x01" +
          "\xde\xad\xbe\xef" +
          "World").force_encoding("ASCII-8BIT")
        @pkt = Memcached::Response.parse_header(s[0..23])
        @pkt.parse_body(s[24..-1])
      end

      it "should return the right class according to magic & opcode" do
        @pkt[:magic].should == 0x81
        @pkt[:opcode].should == 0
        @pkt.class.should == Memcached::Response
      end
      it "should return the right data type" do
        @pkt[:data_type].should == 0
      end
      it "should return the right status" do
        @pkt[:status].should == Memcached::Errors::NO_ERROR
      end
      it "should return the right opaque" do
        @pkt[:opaque].should == 0
      end
      it "should return the right CAS" do
        @pkt[:cas].should == 1
      end
      it "should parse the body correctly" do
        @pkt[:key].should == ""
        @pkt[:value].should == "World"
      end
    end

    describe :parse_body do
      it "should return succeeding bytes" do
        s = "\x81\x01\x00\x00" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x00" +
          "\x00\x00\x00\x01" +
          "chunky bacon"
        @pkt = Memcached::Response.parse_header(s[0..23])
        s = @pkt.parse_body(s[24..-1])
        @pkt[:status].should == 0
        @pkt[:total_body_length].should == 0
        @pkt[:value].should == ""
        s.should == "chunky bacon"
      end
    end
  end
end
