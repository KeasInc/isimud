require 'bunny'
require 'logger'

module Isimud
  class BunnyClient
    DEFAULT_URL = 'amqp://guest:guest@localhost'

    attr_reader :url

    def initialize(_url = nil, _bunny_options = {})
      logger.info "Isimud::BunnyClient.initialize: options = #{_bunny_options.inspect}"
      @url = _url || DEFAULT_URL
      @bunny_options = _bunny_options
    end

    def bind(queue_name, exchange_name, *routing_keys, &block)
      logger.info "Isimud: bind to #{queue_name}: keys #{routing_keys.join(',')}"
      queue = channel.queue(queue_name, durable: true)
      routing_keys.each { |key| queue.bind(exchange_name, routing_key: key, nowait: false) }
      queue.subscribe(ack: true) do |delivery_info, properties, payload|
        begin
          logger.info "Isimud: queue #{queue_name} received #{delivery_info.delivery_tag} routing_key: #{delivery_info.routing_key}"
          Thread.current['isimud_queue_name'] = queue_name
          Thread.current['isimud_delivery_info'] = delivery_info
          Thread.current['isimud_properties'] = properties
          block.call(payload)
          logger.info "Isimud: queue #{queue_name} finished with #{delivery_info.delivery_tag}, acknowledging"
          channel.ack(delivery_info.delivery_tag, true)
        rescue Bunny::Exception => e
          logger.warn("Isimud: queue #{queue_name} error on #{delivery_info.delivery_tag}: #{e.class.name} #{e.message}\n  #{e.backtrace.join("\n  ")}")
          raise
        rescue => e
          logger.warn("Isimud: queue #{queue_name} rejecting #{delivery_info.delivery_tag}: #{e.class.name} #{e.message}\n  #{e.backtrace.join("\n  ")}")
          channel.reject(delivery_info.delivery_tag, true)
        end
        logger.info "Isimud: queue #{queue_name} done with #{delivery_info.delivery_tag}"
      end
      queue
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