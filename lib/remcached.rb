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


    ##
    # Memcached operations
    ##

    def operation(request_klass, contents, &callback)
      client = client_for_key(contents[:key])
      if client
        client.send_request request_klass.new(contents), &callback
      elsif callback
        callback.call :status => Errors::DISCONNECTED
      end
    end

    def add(contents, &callback)
      operation Request::Add, contents, &callback
    end
    def get(contents, &callback)
      operation Request::Get, contents, &callback
    end
    def set(contents, &callback)
      operation Request::Set, contents, &callback
    end
    def delete(contents, &callback)
      operation Request::Delete, contents, &callback
    end


    ##
    # Multi operations
    #
    ##

    def multi_operation(request_klass, contents_list, &callback)
      results = {}

      # Assemble client connections per keys
      client_contents = {}
      contents_list.each do |contents|
        client = client_for_key(contents[:key])
        if client
          client_contents[client] ||= []
          client_contents[client] << contents
        else
          puts "no client for #{contents[:key].inspect}"
          results[contents[:key]] = {:status => Memcached::Errors::DISCONNECTED}
        end
      end

      # send requests and wait for responses per client
      clients_pending = client_contents.length
      client_contents.each do |client,contents_list|
        last_i = contents_list.length - 1
        client_results = {}

        contents_list.each_with_index do |contents,i|
          if i < last_i
            request = request_klass::Quiet.new(contents)
            client.send_request(request) { |response|
              results[contents[:key]] = response
            }
          else # last request for this client
            request = request_klass.new(contents)
            client.send_request(request) { |response|
              results[contents[:key]] = response
              clients_pending -= 1
              if clients_pending < 1
                callback.call results
              end
            }
          end
        end
      end

      self
    end

    def multi_add(contents_list, &callback)
      multi_operation Request::Add, contents_list, &callback
    end

    def multi_get(contents_list, &callback)
      multi_operation Request::Get, contents_list, &callback
    end

    def multi_set(contents_list, &callback)
      multi_operation Request::Set, contents_list, &callback
    end

    def multi_delete(contents_list, &callback)
      multi_operation Request::Delete, contents_list, &callback
    end

  end
end
