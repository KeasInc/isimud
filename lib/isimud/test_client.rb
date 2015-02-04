module Isimud
  class TestClient < Isimud::Client
    attr_accessor :queues

    class Queue
      attr_reader :routing_keys

      def initialize(name, listener)
        @name         = name
        @listener     = listener
        @routing_keys = Set.new
      end

      def add_routing_key(key)
        @routing_keys << Regexp.new(key.gsub(/\./, "\\.").gsub(/\*/, ".*"))
      end

      def has_matching_key?(route)
        @routing_keys.any? { |k| route =~ k }
      end

      def publish(data)
        @listener.call(data)
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

    def bind(queue_name, exchange_name, *keys, &method)
      log "Isimud::TestClient: Binding queue #{queue_name} for keys #{keys.inspect}"
      self.queues[queue_name] ||= Queue.new(queue_name, method)
      keys.each do |k|
        self.queues[queue_name].add_routing_key(k)
      end
    end

    def publish(exchange, routing_key, payload)
      log "Isimud::TestClient: Delivering message exchange: #{exchange} key: #{routing_key} payload: #{payload}"
      self.queues.each do |name, queue|
        if queue.has_matching_key?(routing_key)
          log "Isimud::TestClient: Queue #{name} matches routing key #{routing_key}"
          queue.publish(payload)
        end
      end
    end

    def reset
      self.queues.clear
    end

    def reconnect
      self
    end

    def logger
      Isimud.logger
    end
  end
end
