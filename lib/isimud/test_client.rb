module Isimud
  class TestClient < Isimud::Client
    attr_accessor :queues

    class Queue
      include Isimud::Logging
      attr_reader :name, :routing_keys

      def initialize(name, listener)
        @name         = name
        @listener     = listener
        @routing_keys = Set.new
      end

      def bind(exchange, options = {})
        key = "\\A#{options[:routing_key]}\\Z"
        log "TestClient: adding routing key #{key} to queue #{name}"
        @routing_keys << Regexp.new(key.gsub(/\./, "\\.").gsub(/\*/, ".*"))
      end

      def has_matching_key?(route)
        @routing_keys.any? { |k| route =~ k }
      end

      def deliver(data)
        begin
          @listener.call(data)
        rescue => e
          log "TestClient: error delivering message: #{e.message}\n  #{e.backtrace.join("\n  ")}", :error
          @listener.exception_handler.try(:call, e)
        end
      end
    end

    def initialize(connection = nil, options = nil)
      self.queues = Hash.new
    end

    def connect
      self
    end

    def channel
      self
    end

    def connected?
      true
    end

    def close
    end

    def delete_queue(queue_name)
      queues.delete(queue_name)
    end

    def bind(queue_name, exchange_name, *keys, &method)
      create_queue(queue_name, exchange_name, routing_keys: keys, &method)
    end

    def create_queue(queue_name, exchange_name, options = {}, &method)
      keys = options[:routing_keys] || []
      log "Isimud::TestClient: Binding queue #{queue_name} for keys #{keys.inspect}"
      queue = queues[queue_name] ||= Queue.new(queue_name, method)
      keys.each do |k|
        queue.bind(exchange_name, routing_key: k)
      end
      queue
    end

    def publish(exchange, routing_key, payload)
      log "Isimud::TestClient: Delivering message key: #{routing_key} payload: #{payload}"
      call_queues = queues.values.select { |queue| queue.has_matching_key?(routing_key) }
      call_queues.each do |queue|
        log "Isimud::TestClient: Queue #{queue.name} matches routing key #{routing_key}"
        queue.deliver(payload)
      end
    end

    def reset
      self.queues.clear
    end

    def reconnect
      self
    end
  end
end
