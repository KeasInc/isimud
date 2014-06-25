require 'bunny'

module ModelWatcher

  class BunnyAmqp
    def self.channel
      @connection ||= begin
        connection = Bunny.new
        connection.start
        connection
      end

      @connection.create_channel
    end
  end

  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def watch_attributes(*attributes)
      after_save :send_model_saved_message
    end
  end

  def send_model_saved_message
    channel = ModelWatcher::BunnyAmqp.channel
    exchange = channel.default_exchange
    exchange.publish(self.to_json, routing_key: self.class.model_name.plural)
  end

end
