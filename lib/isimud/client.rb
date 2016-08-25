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

    def find_queue(queue_name, options = {})
    end

    # Declare a proc to be run whenever an uncaught exception is raised within a message processing block.
    # This is useful for logging or monitoring errors, for instance.
    # @yieldparam [Exception] e exception raised
    def on_exception(&block)
      exception_handlers << block
    end

    # Call each of the exception handlers declared by #on_exception.
    # @param [Exception] exception
    # @return [Boolean] true if message should be requeued, false otherwise
    def run_exception_handlers(exception)
      status = true
      exception_handlers.each do |handler|
        status &&= begin
          handler.call(exception)
        rescue
          nil
        end
      end
      Isimud.retry_failures.nil? ? status : Isimud.retry_failures
    end

    def publish(exchange, routing_key, payload, options)
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
