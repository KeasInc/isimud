require 'bunny'
require 'logger'

module Isimud
  class BunnyClient < Isimud::Client
    DEFAULT_URL = 'amqp://guest:guest@localhost'

    attr_reader :url

    def initialize(_url = nil, _bunny_options = {})
      log "Isimud::BunnyClient.initialize: options = #{_bunny_options.inspect}"
      @url           = _url || DEFAULT_URL
      @bunny_options = _bunny_options
    end

    # Convenience method to find or create a queue, bind to the exchange, and subscribe to messages
    def bind(queue_name, exchange_name, *routing_keys, &block)
      queue = create_queue(queue_name, exchange_name,
                           queue_options: {durable: true},
                           routing_keys:  routing_keys)
      subscribe(queue, &block) if block_given?
    end

    # Find or create a named queue and bind it to the specified exchange
    def create_queue(queue_name, exchange_name, options = {})
      queue_options     = options[:queue_options] || {durable: true}
      routing_keys      = options[:routing_keys] || []
      log "Isimud::BunnyClient: create_queue #{queue_name}: queue_options=#{queue_options.inspect}"
      queue = find_queue(queue_name, queue_options)
      bind_routing_keys(queue, exchange_name, routing_keys) if routing_keys.any?
      queue
    end

    # Subscribe to messages on the named queue. Returns the consumer
    def subscribe(queue, options = {manual_ack: true}, &block)
      current_channel = channel
      queue.subscribe(options) do |delivery_info, properties, payload|
        begin
          log "Isimud: queue #{queue.name} received #{delivery_info.delivery_tag} routing_key: #{delivery_info.routing_key}"
          Thread.current['isimud_queue_name']    = queue.name
          Thread.current['isimud_delivery_info'] = delivery_info
          Thread.current['isimud_properties']    = properties
          block.call(payload)
          log "Isimud: queue #{queue.name} finished with #{delivery_info.delivery_tag}, acknowledging"
          current_channel.ack(delivery_info.delivery_tag)
        rescue => e
          log("Isimud: queue #{queue.name} error processing #{delivery_info.delivery_tag} payload #{payload.inspect}: #{e.class.name} #{e.message}\n  #{e.backtrace.join("\n  ")}", :warn)
          current_channel.reject(delivery_info.delivery_tag, Isimud.retry_failures)
          run_exception_handlers(e)
        end
      end
    end

    # Permanently delete the queue from the broker
    def delete_queue(queue_name)
      channel.queue_delete(queue_name)
    end

    def connection
      @connection ||= ::Bunny.new(url, @bunny_options).tap(&:start)
    end

    alias connect connection

    CHANNEL_KEY = :'isimud.bunny_client.channel'

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

    def reset
      connection.close_all_channels
    end

    def connected?
      @connection && @connection.open?
    end

    def close
      connection.close
    ensure
      @connection = nil
    end

    def publish(exchange, routing_key, payload)
      channel.topic(exchange, durable: true).publish(payload, routing_key: routing_key, persistent: true)
    end

    def reconnect
      close
      connect
    end

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