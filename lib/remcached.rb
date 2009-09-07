require 'remcached/const'
require 'remcached/packet'

module Memcached
  class << self
    def new(servers)
      raise 'Hashing not supported right now' if servers.length != 1
      @servers = servers
    end
  
    def get(keys)
      keys.collect! { |key| key.gsub(/[ \t\r\n]/, '_') }
    end

    def set(keys)
    end

    private

    def server_for_key(key)
      # TODO: how many are alive?
      h = self.class.hash_key(key) % @servers.length
      @servers[h]
    end
  end

  # Used internally, exposed for testing
  def hash_key(key)
    hashed = 0
    key.bytes.each_with_index do |c, p|
      p = (3 - p) * 8
      hashed ^= c << p
    end
    hashed
  end
end
