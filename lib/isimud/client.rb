module Isimud
  # @abstract Messaging queue service client
  class Client
    include Isimud::Logging

    def initialize(server = nil, options = nil)
    end

    def connect
    end

    def channel
    end

    def connected?
    end

    def close
    end

    def bind(queue_name, exchange_name, *keys, &method)
    end

    def publish(exchange, routing_key, payload)
    end

    def reset
    end

    def reconnect
    end

    def logger
      Isimud.logger
    end
  end
end

require 'isimud/bunny_client'
require 'isimud/test_client'
