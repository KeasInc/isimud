module Isimud
  # @abstract Messaging queue service client
  class Client
    include Isimud::Logging

    attr_reader :exception_handler

    def initialize(server = nil, options = nil)
    end

    def bind(queue_name, exchange_name, *keys, &method)
    end

    def channel
    end

    def close
    end

    def connect
    end

    def connected?
    end

    def create_queue(queue_name, exchange_name, options = {}, &method)
    end

    def delete_queue(queue_name)
    end

    def on_exception(&block)
      @exception_handler = block
    end

    def publish(exchange, routing_key, payload)
    end

    def reconnect
    end

    def rebind(queue_name, exchange_name, *keys)
    end

    def reset
    end
  end
end

require 'isimud/bunny_client'
require 'isimud/test_client'
