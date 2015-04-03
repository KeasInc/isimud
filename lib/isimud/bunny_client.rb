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

    def bind(queue_name, exchange_name, *routing_keys, &block)
      create_queue(queue_name, exchange_name,
                   queue_options:     {durable: true},
                   routing_keys:      routing_keys,
                   subscribe_options: {manual_ack: true}, &block)
    end

    def create_queue(queue_name, exchange_name, options = {}, &block)
      queue_options     = options[:queue_options] || {}
      routing_keys      = options[:routing_keys] || []
      subscribe_options = options[:subscribe_options] || {}
      log "Isimud: create_queue #{queue_name}: queue_options=#{queue_options.inspect} routing_keys=#{routing_keys.join(',')} subscribe_options=#{subscribe_options.inspect}"
      current_channel = channel
      queue           = current_channel.queue(queue_name, queue_options)
      routing_keys.each { |key| queue.bind(exchange_name, routing_key: key, nowait: false) }
      queue.subscribe(subscribe_options) do |delivery_info, properties, payload|
        begin
          log "Isimud: queue #{queue_name} received #{delivery_info.delivery_tag} routing_key: #{delivery_info.routing_key}"
          Thread.current['isimud_queue_name']    = queue_name
          Thread.current['isimud_delivery_info'] = delivery_info
          Thread.current['isimud_properties']    = properties
          block.call(payload)
          log "Isimud: queue #{queue_name} finished with #{delivery_info.delivery_tag}, acknowledging"
          current_channel.ack(delivery_info.delivery_tag)
        rescue => e
          log("Isimud: queue #{queue_name} error processing #{delivery_info.delivery_tag} payload #{payload.inspect}: #{e.class.name} #{e.message}\n  #{e.backtrace.join("\n  ")}", :warn)
          current_channel.reject(delivery_info.delivery_tag, Isimud.retry_failures)
          raise
        end
      end
      queue
    end

    def delete_queue(queue_name)
      channel.queue(queue_name).delete
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

    def exception_handler(&block)
      channel.on_uncaught_exception do
        yield
      end
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
  end
end