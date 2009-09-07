module Memcached
  class Connection < EventMachine::Connection
    def initialize(*a)
      super
      @opaque_counter = 0
      @callbacks = {}
      @recv_buf = ""
      @recv_state = :header
    end

    ##
    # Request header:
    #
    #   Byte/     0       |       1       |       2       |       3       |
    #      /              |               |               |               |
    #     |0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|
    #     +---------------+---------------+---------------+---------------+
    #    0| Magic         | Opcode        | Key length                    |
    #     +---------------+---------------+---------------+---------------+
    #    4| Extras length | Data type     | Reserved                      |
    #     +---------------+---------------+---------------+---------------+
    #    8| Total body length                                             |
    #     +---------------+---------------+---------------+---------------+
    #   12| Opaque                                                        |
    #     +---------------+---------------+---------------+---------------+
    #   16| CAS                                                           |
    #     |                                                               |
    #     +---------------+---------------+---------------+---------------+
    #     Total 24 bytes
    def send_request(opcode, key, value, opaque, extras="", cas=0, &callback)
      magic = 0x80
      data_type = Datatypes::RAW_BYTES
      opaque = (@opaque_counter += 1)
      body = extras + key + value
      header = [magic, opcode, key_length,
                extras.length, data_type, 0,
                body.length,
                opaque,
                cas
               ].pack('CCnCCnNNQ')
      pkt = header + body
      send_data pkt

      if callback
        @callbacks[opaque] = callback
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
  end
end
