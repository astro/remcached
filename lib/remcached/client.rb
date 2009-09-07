require 'eventmachine'

module Memcached
  class Connection < EventMachine::Connection
    def self.connect(host, port=11211, &connect_callback)
      df = EventMachine::DefaultDeferrable.new
      df.callback &connect_callback

      EventMachine.connect(host, port, self) do |me|
        me.instance_eval { 
          @host, @port = host, port
          @connect_deferrable = df
        }
      end
    end

    def reconnect
      @connect_deferrable = EventMachine::DefaultDeferrable.new
      super @host, @port
      @connect_deferrable
    end

    def post_init
      @recv_buf = ""
      @recv_state = :header
    end

    def connection_completed
      @connect_deferrable.succeed(self)
    end

    def unbind
p :unbind
      # TODO: delayed!
      #reconnect
    end

    def send_packet(pkt)
      send_data pkt.to_s
    end

    def receive_data(data='')
      @recv_buf += data

      if @recv_state == :header && @recv_buf.length >= 24
        @received = Response.parse_header(@recv_buf[0..23])
        @recv_buf = @recv_buf[24..-1]
        @recv_state = :body
        receive_data

      elsif @recv_state == :body && @recv_buf.length >= @received[:total_body_length]
        @recv_buf = @received.parse_body(@recv_buf)
        receive_packet(@received)

        @recv_state = :header
        receive_data

      end
    end
  end

  class Client < Connection
    def post_init
      super
      @opaque_counter = 0
      @pending = []
    end

    def send_request(pkt, &callback)
      @opaque_counter += 1
      @opaque_counter %= 1 << 32
      pkt[:opaque] = @opaque_counter
      send_packet pkt

      if callback
        @pending << [@opaque_counter, callback]
      end
    end

    ##
    # memcached responses possess the same order as their
    # corresponding requests. Therefore quiet requests that have not
    # yielded responses will be dropped silently to free memory from
    # +@pending+
    def receive_packet(response)
      pending_pos = nil
      pending_callback = nil
      @pending.each_with_index do |(pending_opaque,pending_cb),i|
        if response[:opaque] == pending_opaque
          pending_pos = i
          pending_callback = pending_cb
          break
        end
      end

      if pending_pos
        @pending = @pending[(pending_pos+1)..-1]
        pending_callback.call response
      end
    end


    def get(contents, &callback)
      send_request Request::Get.new(contents), &callback
    end

    def add(contents, &callback)
      send_request Request::Add.new(contents), &callback
    end

    def set(contents, &callback)
      send_request Request::Set.new(contents), &callback
    end

    def delete(contents, &callback)
      send_request Request::Delete.new(contents), &callback
    end

  end
end
