require 'remcached/const'
require 'remcached/packet'
require 'remcached/client'

module Memcached
  class << self
    ##
    # +servers+: Array of host:port strings
    def servers=(servers)
      if defined?(@clients) && @clients
        while client = @clients.shift
          begin
            client.close
          rescue Exception
            # This is allowed to fail silently
          end
        end
      end

      @clients = servers.collect { |server|
        host, port = server.split(':')
        Client.connect host, (port ? port.to_i : 11211)
      }
    end
  
    def usable?
      usable_clients.length > 0
    end

    def usable_clients
      unless defined?(@clients) && @clients
        []
      else
        @clients.select { |client| client.connected? }
      end
    end

    def client_for_key(key)
      usable_clients_ = usable_clients
      if usable_clients_.empty?
        nil
      else
        h = hash_key(key) % usable_clients_.length
        usable_clients_[h]
      end
    end

    def hash_key(key)
      hashed = 0
      i = 0
      key.each_byte do |b|
        j = key.length - i - 1 % 4
        hashed ^= b << (j * 8)
        i += 1
      end
      hashed
    end

    def operation(op, contents, &callback)
      client = client_for_key(contents[:key])
      if client
        client.send(op, contents, &callback)
      elsif callback
        callback.call :status => Errors::DISCONNECTED
      end
    end


    ##
    # Memcached operations
    ##

    def add(contents, &callback)
      operation :add, contents, &callback
    end
    def get(contents, &callback)
      operation :get, contents, &callback
    end
    def set(contents, &callback)
      operation :set, contents, &callback
    end
    def delete(contents, &callback)
      operation :delete, contents, &callback
    end
  end
end
