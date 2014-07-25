module Isimud
  class TestClient
    class Queue
      def initialize(name, listener)
        @name         = name
        @listener     = listener
        @routing_keys = Set.new
      end

      def add_routing_key(key)
        @routing_keys << Regexp.new(key.gsub(/\./, "\\.").gsub(/\*/, ".*"))
      end

      def matches(routing_key)
        @routing_keys.any? { |k| routing_key =~ k }
      end

      def publish(data)
        @listener.call(data)
      end
    end

    def initialize(connection = nil, options = nil)
      @queues = Hash.new
    end

    def connect
      self
    end

    def channel
      self
    end

    def close
    end

    def bind(queue_name, exchange_name, *keys, &method)
      logger.info "Isimud::TestClient: Binding queue #{queue_name} for keys #{keys.inspect}"
      @queues[queue_name] ||= Queue.new(queue_name, method)
      keys.each do |k|
        @queues[queue_name].add_routing_key(k)
      end
    end

    def publish(exchange, routing_key, payload)
      logger.debug "Isimud::TestClient: Delivering message exchange: #{exchange} key: #{routing_key} payload: #{payload}"
      @queues.each do |name, queue|
        if queue.matches(routing_key)
          logger.debug "Isimud::TestClient: Queue #{name} matches routing key #{routing_key}"
          queue.publish(payload)
        end
      end
    end

    def reconnect
      self
    end

    def logger
      Isimud.logger
    end
  end
end
