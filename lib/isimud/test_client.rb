module Isimud

  # Interface for a messaging client that is suitable for testing. No network connections are used.
  # All message deliveries are handled in a synchronous manner. When a message is published to the client, each declared
  # queue is examined and, if the message's routing key matches any of the patterns bound to the queue, the queue's
  # block is called with the message. Any uncaught exceptions raised within a message processing
  # block will cause any declared exception handlers to be run. However, the message will not be re-queued should this
  # occur.
  class TestClient < Isimud::Client
    attr_accessor :queues

    class Queue
      include Isimud::Logging
      attr_reader :name, :bindings, :client
      attr_accessor :proc

      def initialize(client, name, proc = Proc.new { |_|})
        @client   = client
        @name     = name
        @bindings = Hash.new { |hash, key| hash[key] = Set.new }
        @proc     = proc
      end

      def bind(exchange, opts = {})
        routing_key = opts[:routing_key]
        log "TestClient: adding routing key #{routing_key} for exchange #{exchange} to queue #{name}"
        @bindings[exchange] << routing_key
      end

      def cancel
      end

      def delete(opts = {})
        log "TestClient: delete queue #{name}"
        @bindings.clear
        @proc = nil
      end

      def unbind(exchange, opts = {})
        routing_key = opts[:routing_key]
        log "TestClient: removing routing key #{routing_key} for exchange #{exchange} from queue #{name}"
        @bindings[exchange].delete(routing_key)
      end

      def make_regexp(key)
        Regexp.new(key.gsub(/\./, "\\.").gsub(/\*/, '[^.]*').gsub(/#/, '.*'))
      end

      def has_matching_key?(exchange, route)
        @bindings[exchange].any? { |key| route =~ make_regexp(key) }
      end

      def deliver(data)
        begin
          @proc.try(:call, data)
        rescue => e
          log "TestClient: error delivering message: #{e.message}\n  #{e.backtrace.join("\n  ")}", :error
          client.run_exception_handlers(e)
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
      log "Isimud::TestClient: deleting queue #{queue_name}"
      queues.delete(queue_name)
    end

    def bind(queue_name, exchange_name, *keys, &block)
      queue = create_queue(queue_name, exchange_name, routing_keys: keys)
      subscribe(queue, &block)
    end

    def find_queue(queue_name, _options = {})
      queues[queue_name] ||= Queue.new(self, queue_name)
    end

    def create_queue(queue_name, exchange_name, options = {})
      keys = options[:routing_keys] || []
      log "Isimud::TestClient: Binding queue #{queue_name} on exchange #{exchange_name} for keys #{keys.inspect}"
      queue = find_queue(queue_name)
      keys.each do |k|
        queue.bind(exchange_name, routing_key: k)
      end
      queue
    end

    def subscribe(queue, _options = {}, &block)
      log "Isimud::TestClient: subscribing to events on queue #{queue.name}"
      queue.proc = block
      queue
    end

    def publish(exchange, routing_key, payload, _options = {})
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
