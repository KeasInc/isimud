module Isimud
  # @abstract Messaging queue service client
  class Client
    include Isimud::Logging

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

    def create_queue(queue_name, exchange_name, options = {})
    end

    def delete_queue(queue_name)
    end

    def on_exception(&block)
      exception_handlers << block
    end

    def run_exception_handlers(exception)
      exception_handlers.each{|handler| handler.call(exception)}
    end

    def publish(exchange, routing_key, payload)
    end

    def reconnect
    end

    def reset
    end

    def subscribe(queue, options = {}, &block)
    end

    private

    def exception_handlers
      @exception_handlers ||= Array.new
    end
  end
end

require 'isimud/bunny_client'
require 'isimud/test_client'
