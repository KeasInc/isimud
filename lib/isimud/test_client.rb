module Isimud
  class TestClient < Isimud::Client
    attr_accessor :queues

    class Queue
      include Isimud::Logging
      attr_reader :name, :bindings
      attr_accessor :proc

      def initialize(name, proc = Proc.new{ |_| } )
        @name         = name
        @bindings     = Hash.new{ |hash, key| hash[key] = Set.new }
        @proc         = proc
      end

      def bind(exchange, routing_key)
        log "TestClient: adding routing key #{routing_key} for exchange #{exchange} to queue #{name}"
        @bindings[exchange] << routing_key
      end

      def cancel
        @proc = nil
      end

      def delete(opts = {})
        @bindings.clear
      end

      def unbind(exchange, routing_key)
        @bindings[exchange].delete(routing_key)
      end

      def make_regexp(key)
        Regexp.new(key.gsub(/\./, "\\.").gsub(/\*/, '.*'))
      end

      def has_matching_key?(exchange, route)
        @bindings[exchange].any? { |key| route =~ make_regexp(key) }
      end

      def deliver(data)
        begin
          @proc.try(:call, data)
        rescue => e
          log "TestClient: error delivering message: #{e.message}\n  #{e.backtrace.join("\n  ")}", :error
          exception_handler.try(:call, e)
        end
      end
    end

    def initialize(connection = nil, options = {})
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

    def find_queue(queue_name)
      queues[queue_name] ||= Queue.new(queue_name)
    end

    def create_queue(queue_name, exchange_name, options = {}, &method)
      keys = options[:routing_keys] || []
      log "Isimud::TestClient: Binding queue #{queue_name} for keys #{keys.inspect}"
      queue = find_queue(queue_name)
      keys.each do |k|
        queue.bind(exchange_name, k)
      end
      queue.proc = method if block_given?
      queue
    end

    def publish(exchange, routing_key, payload)
      log "Isimud::TestClient: Delivering message exchange: #{exchange} key: #{routing_key} payload: #{payload}"
      call_queues = queues.values.select { |queue| queue.has_matching_key?(exchange, routing_key) }
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
