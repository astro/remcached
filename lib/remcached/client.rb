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
p :connecting
    end

    def reconnect
      @connect_deferrable = EventMachine::DefaultDeferrable.new
      super @host, @port
      @connect_deferrable
    end

    def initialize(*a)
      super
      @opaque_counter = 0
      @callbacks = {}
      @recv_buf = ""
      @recv_state = :header
    end

    def connection_completed
p :connection_completed
      @connect_deferrable.succeed
    end

    def unbind
      # TODO: delayed!
      reconnect
    end

    def send_request(pkt, &callback)
      @opaque_counter += 1
      @opaque_counter %= 1 << 32
      pkt[:opaque] = @opaque_counter
      send_data pkt.to_s

      if callback
        @callbacks[@opaque_counter] = callback
      end
    end

    def receive_data(data='')
      @recv_buf += data

      if @state == :header && @recv_buf.length >= 24
        @response = Response.parse_header(@recv_buf[0..23])
        @recv_buf = @recv_buf[24..-1]
        @state = :body
        receive_data

      elsif @state == :body && @recv_buf.length >= @response.total_body_length
        @received.parse_body @recv_buf
        receive_response(@response[0..(@received.total_body_length - 1)])

        @recv_buf = @recv_buf[@received.total_body_length..-1]
        @state = :header
        receive_data

      end
    end
  end

  class Server < Connection

    def receive_response(response)
      p :response => response
    end
  end
end
