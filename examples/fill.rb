#!/usr/bin/env ruby

# Experimentally determine how many items fit in your memcached
# instance. Adjust parameters below for your scenario.

BATCH_SIZE = 10000
KEY_SIZE = 26
VALUE_SIZE = 0


$: << File.dirname(__FILE__) + "/../lib"
require 'remcached'

EM.run do
  @total = 0

  # Action
  def fill
    old_total = @total

    reqs = (1..BATCH_SIZE).map {
      @total += 1
      { :key => sprintf("%0#{KEY_SIZE}X", @total),
        :value => sprintf("%0#{VALUE_SIZE}X", @total)
      }
    }
    Memcached.multi_add(reqs) do |resps|
      resps.each do |key,resp|
        case resp[:status]
        when Memcached::Errors::NO_ERROR
          :ok
        when Memcached::Errors::KEY_EXISTS
          @total -= 1
        else
          puts "Cannot set #{key}: status=#{resp[:status].inspect}"
          @total -= 1
        end
      end

      puts "Added #{@total - old_total}, now: #{@total}"
      if Memcached.usable?
        stats = {}
        Memcached.usable_clients[0].stats do |resp|
          if resp[:key] != ''
            stats[resp[:key]] = resp[:value]
          else
            puts "Stats: #{stats['bytes']} bytes in #{stats['curr_items']} of #{stats['total_items']} items"
          end
        end

        # Next round:
        fill
      else
        EM.stop
      end
    end
  end

  # Initialization & start
  Memcached.servers = %w(localhost)
  @t = EM::PeriodicTimer.new(0.01) do
    if Memcached.usable?
      puts "Connected to server"
      @t.cancel
      fill
    else
      puts "Waiting for server connection..."
    end
  end
end
