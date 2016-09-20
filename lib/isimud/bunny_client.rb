require 'bunny'
require 'logger'

module Isimud

  # Interface for Bunny RabbitMQ client
  # @see http://rubybunny.info
  class BunnyClient < Isimud::Client
    DEFAULT_URL = 'amqp://guest:guest@localhost'

    attr_reader :url

    # Initialize a new BunnyClient instance. Note that a connection is not established until any other method is called
    #
    # @param [String, Hash] _url Server URL or options hash
    # @param [Hash] _bunny_options optional Bunny connection options
    # @see Bunny.new for connection options
    def initialize(_url = nil, _bunny_options = {})
      log "Isimud::BunnyClient.initialize: options = #{_bunny_options.inspect}"
      @url = _url || DEFAULT_URL
      @url.symbolize_keys! if @url.respond_to?(:symbolize_keys!)
      @bunny_options = _bunny_options.symbolize_keys
      @bunny_options[:logger] = Isimud.logger
    end

    # Convenience method that finds or creates a named queue, binds to an exchange, and subscribes to messages.
    # If a block is provided, it will be called by the consumer each time a message is received.
    #
    # @param [String] queue_name name of the queue
    # @param [String] exchange_name name of the AMQP exchange. Note that existing exchanges must be declared as Topic
    #   exchanges; otherwise, an error will occur
    # @param [Array<String>] routing_keys list of routing keys to be bound to the queue for the specified exchange.
    # @yieldparam [String] payload message text
    # @return [Bunny::Consumer] Bunny consumer interface
    def bind(queue_name, exchange_name, *routing_keys, &block)
      queue = create_queue(queue_name, exchange_name,
                           queue_options: {durable: true},
                           routing_keys:  routing_keys)
      subscribe(queue, &block) if block_given?
    end

    # Find or create a named queue and bind it to the specified exchange
    #
    # @param [String] queue_name name of the queue
    # @param [String] exchange_name name of the AMQP exchange. Note that pre-existing exchanges must be declared as Topic
    #   exchanges; otherwise, an error will occur
    # @param [Hash] options queue declaration options
    # @option options [Boolean] :queue_options ({durable: true}) queue declaration options -- @see Bunny::Channel#queue
    # @option options [Array<String>] :routing_keys ([]) routing keys to be bound to the queue. Use "*" to match any 1 word
    #   in a route segment. Use "#" to match 0 or more words in a segment.
    # @return [Bunny::Queue] Bunny queue
    def create_queue(queue_name, exchange_name, options = {})
      queue_options = options[:queue_options] || {durable: true}
      routing_keys  = options[:routing_keys] || []
      log "Isimud::BunnyClient: create_queue #{queue_name}: queue_options=#{queue_options.inspect}"
      queue = find_queue(queue_name, queue_options)
      bind_routing_keys(queue, exchange_name, routing_keys) if routing_keys.any?
      queue
    end

    # Subscribe to messages on the Bunny queue. The provided block will be called each time a message is received.
    #   The message will be acknowledged and deleted from the queue unless an exception is raised from the block.
    #   In the case that an uncaught exception is raised, the message is rejected, and any declared exception handlers
    #   will be called.
    #
    # @param [Bunny::Queue] queue Bunny queue
    # @param [Hash] options {} subscription options -- @see Bunny::Queue#subscribe
    # @yieldparam [String] payload message text
    def subscribe(queue, options = {}, &block)
      queue.subscribe(options.merge(manual_ack: true)) do |delivery_info, properties, payload|
        current_channel = delivery_info.channel
        begin
          log "Isimud: queue #{queue.name} received #{properties[:message_id]} routing_key: #{delivery_info.routing_key}", :debug
          Thread.current['isimud_queue_name']    = queue.name
          Thread.current['isimud_delivery_info'] = delivery_info
          Thread.current['isimud_properties']    = properties
          block.call(payload)
          if current_channel.open?
            log "Isimud: queue #{queue.name} finished with #{properties[:message_id]}, acknowledging", :debug
            current_channel.ack(delivery_info.delivery_tag)
          else
            log "Isimud: queue #{queue.name} unable to acknowledge #{properties[:message_id]}", :warn
          end
        rescue => e
          log("Isimud: queue #{queue.name} error processing #{properties[:message_id]} payload #{payload.inspect}: #{e.class.name} #{e.message}\n  #{e.backtrace.join("\n  ")}", :warn)
          retry_status = run_exception_handlers(e)
          log "Isimud: rejecting #{properties[:message_id]} requeue=#{retry_status}", :warn
          current_channel.open? && current_channel.reject(delivery_info.delivery_tag, retry_status)
        end
      end
    end

    # Permanently delete the queue from the AMQP server. Any messages present in the queue will be discarded.
    # @param [String] queue_name queue name
    # @return [AMQ::Protocol::Queue::DeleteOk] RabbitMQ response
    def delete_queue(queue_name)
      channel.queue_delete(queue_name)
    end

    # Establish a connection to the AMQP server, or return the current connection if one already exists
    # @return [Bunny::Session]
    def connection
      @connection ||= ::Bunny.new(url, @bunny_options).tap(&:start)
    end

    alias connect connection

    CHANNEL_KEY = :'isimud.bunny_client.channel'

    # Open a new, thread-specific AMQP connection channel, or return the current channel for this thread if it exists
    #   and is currently open. New channels are created with publisher confirms enabled. Messages will be prefetched
    #   according to Isimud.prefetch_count when declared.
    # @return [Bunny::Channel] channel instance.
    def channel
      if (channel = Thread.current[CHANNEL_KEY]).try(:open?)
        channel
      else
        new_channel = connection.channel
        new_channel.confirm_select
        new_channel.prefetch(Isimud.prefetch_count) if Isimud.prefetch_count
        Thread.current[CHANNEL_KEY] = new_channel
      end
    end

    # Reset this client by closing all channels for the connection.
    def reset
      connection.close_all_channels
    end

    # Determine if a Bunny connection is currently established to the AMQP server.
    # @return [Boolean,nil] true if a connection was established and is active or starting, false if a connection exists
    # but is closed or closing, or nil if no connection has been established.
    def connected?
      @connection && @connection.open?
    end

    # Close the AMQP connection and clear it from the instance.
    # @return nil
    def close
      connection.close
    ensure
      @connection = nil
    end

    # Publish a message to the specified exchange, which is declared as a durable, topic exchange. Note that message
    #   is always persisted.
    # @param [String] exchange AMQP exchange name
    # @param [String] routing_key message routing key. This should always be in the form of words separated by dots
    #   e.g. "user.goal.complete"
    # @param [String] payload message payload
    # @param [Hash] options additional message options
    # @see Bunny::Exchange#publish
    # @see http://rubybunny.info/articles/exchanges.html
    def publish(exchange, routing_key, payload, options = {})
      log "Isimud::BunnyClient#publish: exchange=#{exchange} routing_key=#{routing_key}", :debug
      channel.topic(exchange, durable: true).publish(payload, options.merge(routing_key: routing_key, persistent: true))
    end

    # Close and reopen the AMQP connection
    # @return [Bunny::Session]
    def reconnect
      close
      connect
    end

    # Look up a queue by name, or create it if it does not already exist.
    def find_queue(queue_name, options = {durable: true})
      channel.queue(queue_name, options)
    end

    private

    def bind_routing_keys(queue, exchange_name, routing_keys)
      log "Isimud::BunnyClient: bind queue #{queue.name} exchange #{exchange_name} routing_keys: #{routing_keys.join(',')}"
      channel.exchange(exchange_name, type: :topic, durable: true)
      routing_keys.each { |key| queue.bind(exchange_name, routing_key: key, nowait: false) }
    end

  end
end