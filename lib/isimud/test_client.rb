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

    def initialize
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

    def bind(name, *keys, &method)
      logger.info "Synchronous: Binding event #{name} for keys #{keys}"
      @queues[name] ||= Queue.new(name, method)
      keys.each do |k|
        @queues[name].add_routing_key(k)
      end
    end

    def publish(data, routing_key)
      logger.debug "Delivering synchronous event #{data}"
      @queues.each do |name, queue|
        queue.publish(data) if queue.matches(routing_key)
      end
    end

    def reconnect
      self
    end
  end
end
