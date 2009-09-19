remcached
=========

* **Ruby EventMachine memCACHED client implementation**
* provides a direct interface to the memcached protocol and its
  semantics
* uses the memcached `binary protocol`_ to reduce parsing overhead on
  the server side (requires memcached >= 1.3)
* supports multiple servers with simple round-robin key hashing
  (**TODO:** implement the libketama algorithm) in a fault-tolerant
  way
* writing your own abstraction layer is recommended
* uses RSpec
* partially documented in RDoc-style


Callbacks
---------

Each request `may` be passed a callback. These are not two-cased
(success & failure) EM deferrables, but standard Ruby callbacks. The
rationale behind this is that there are no usual success/failure
responses, but you will want to evaluate a ``response[:status]``
yourself to check for cache miss, version conflict, network
disconnects etc.

A callback may be kept if it returns ``:proceed`` to catch
multi-response commands such as ``STAT``.

remcached has been built with **fault tolerance** in mind: a callback
will be called with just ``{:status => Memcached::Errors::DISCONNECTED}``
if the network connection has went away. Thus, you can expect your
callback will be called, except of course you're using `quiet`
commands. In that case, only a "non-usual response" from the server or
a network failure will invoke your block.


Multi commands
--------------

The technique is described in the `binary protocol`_ spec in section
**4.2**. ``Memcached.multi_operation`` will help you exactly with
that, sending lots of those `quiet` commands, except for the last,
which will be a `normal` command to trigger an acknowledge for all
commands.

This is of course implemented per-server to accomodate
load-balancing.


Usage
-----

First, pass your memcached servers to the library::

    Memcached.servers = %w(localhost localhost:11212 localhost:11213)

Note that it won't be connected immediately. Use ``Memcached.usable?``
to check. This however complicates your own code and you can check
``response[:status] == Memcached::Errors::DISCONNECTED`` for network
errors in all your response callbacks.

Further usage is pretty straight-forward::

    Memcached.get(:key => 'Hello') do |response|
      case response[:status]
        when Memcached::Errors::NO_ERROR
          use_cached_value response[:value] # ...
        when Memcached::Errors::KEY_NOT_FOUND
          refresh_cache! # ...
        when Memcached::Errors::DISCONNECTED
          proceed_uncached # ...
        else
          cry_for_help # ...
        end
      end
    end
    Memcached.set(:key => 'Hello', :value => 'World',
                  :expiration => 600) do |response|
      case response[:status]
        when Memcached::Errors::NO_ERROR
          # That's good
        when Memcached::Errors::DISCONNECTED
	  # Maybe stop filling the cache for now?
        else
          # What could've gone wrong?
        end
      end
    end

Multi-commands may require a bit of precaution::

    Memcached.multi_get([{:key => 'foo'},
                         {:key => 'bar'}]) do |responses|
      # responses is now a hash of Key => Response
    end

It's not guaranteed that any of these keys will be present in the
response. Moreover, they may be present even if they are a usual
response because the last request is always non-quiet.


**HAPPY CACHING!**

.. _binary protocol: http://code.google.com/p/memcached/wiki/MemcacheBinaryProtocol
