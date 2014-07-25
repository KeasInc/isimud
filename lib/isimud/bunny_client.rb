require 'bunny'
require 'logger'

module Isimud
  class BunnyClient
    DEFAULT_URL = 'amqp://guest:guest@localhost'

    attr_reader :url

    def initialize(_url = nil)
      @url = _url || DEFAULT_URL
    end

    def bind(queue_name, exchange_name, *routing_keys, &block)
      logger.info "Isimud: bind to #{queue_name}: keys #{routing_keys.join(',')}"
      queue = channel.queue(queue_name, durable: true)
      routing_keys.each { |key| queue.bind(exchange_name, routing_key: key, nowait: false) }
      queue.subscribe(ack: true) do |delivery_info, properties, payload|
        begin
          logger.info "Isimud: queue #{queue_name} received: #{delivery_info.inspect} properties: #{properties.inspect}"
          Thread.current['isimud_queue_name'] = queue_name
          Thread.current['isimud_delivery_info'] = delivery_info
          Thread.current['isimud_properties'] = properties
          block.call(payload)
          logger.info "Isimud: finished with #{delivery_info.delivery_tag}, acknowledging"
          channel.ack(delivery_info.delivery_tag)
        rescue => e
          logger.warn("Isimud: error on #{delivery_info.delivery_tag}: #{e.message}\n  #{e.backtrace.join("\n  ")}")
          channel.reject(delivery_info.delivery_tag, true)
        end
      end
      queue
    end

    def connection
      @connection ||= ::Bunny.new(url).tap(&:start)
    end

    alias connect connection

    CHANNEL_KEY = :'isimud.bunny_client.channel'

    def channel
      if (channel = Thread.current[CHANNEL_KEY]).try(:open?)
        channel
      else
        new_channel = connection.channel
        new_channel.confirm_select
        Thread.current[CHANNEL_KEY] = new_channel
      end
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

    def logger
      Isimud.logger
    end
  end
end