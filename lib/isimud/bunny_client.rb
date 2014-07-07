require 'logger'

module Isimud
  class BunnyClient
    DEFAULT_URL = 'amqp://guest:guest@localhost'

    attr_reader :url, :connection

    def initialize(_url = nil)
      @url = _url || DEFAULT_URL
    end

    def bind(queue_name, exchange_name, *routing_keys, &block)
      logger.info "Isimud: bind to #{queue_name}: keys #{routing_keys.join(',')}"
      queue = channel.queue(queue_name, durable: true)
      routing_keys.each { |key| queue.bind(exchange_name, routing_key: key, nowait: false) }
      queue.subscribe(ack: true) do |delivery_info, properties, payload|
        logger.debug "Isimud: received #{payload} properties: #{properties.inspect}"
        block.call(payload)
        channel.ack(delivery_info.delivery_tag)
      end
      queue
    end

    def connection
      @connection ||= Bunny.new(url).tap(&:start)
    end

    def channel
      if (channel = Thread.current[:'isimud.bunny_client.channel']).try(:open?)
        channel
      else
        Thread.current[:'isimud.bunny_client.channel'] = connection.channel
      end
    end

    def close
      connection.close
    end

    def publish(exchange, routing_key, payload)
      channel.topic(exchange, durable: true).publish(payload, routing_key: routing_key, persistent: true)
    end
  end
end