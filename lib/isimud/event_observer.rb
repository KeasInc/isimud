require 'active_record'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

# Module for attaching and listening to events
#
# Note: the following columns must be defined in your model:
#   :exchange_routing_keys text
module Isimud
  module EventObserver
    extend ::ActiveSupport::Concern
    include Isimud::Logging

    mattr_accessor :observed_models do
      Array.new
    end

    mattr_accessor :observed_mutex do
      Mutex.new
    end

    included do
      register_class
      before_save :set_routing_keys
      serialize :exchange_routing_keys, Array
      after_commit :create_queue, on: :create, if: :enable_listener?, prepend: true
      after_commit :update_queue, on: :update, prepend: true
      after_commit :delete_queue, on: :destroy, prepend: true
      include Isimud::ModelWatcher unless self.include?(Isimud::ModelWatcher)
    end

    # Event handling hook. Override in your class.
    def handle_event(event)
      logger.warn("Isimud::EventObserver#handle_event not implemented for #{event_queue_name}")
    end

    # Routing keys that are bound to the event queue. Override in your subclass
    def routing_keys
      []
    end

    # Returns true if this instance is enabled for listening to events. Override in your subclass.
    def enable_listener?
      true
    end

    # Exchange used for listening to events. Override in your subclass if you want to specify an alternative exchange.
    def observed_exchange
      nil
    end

    # Create or attach to a queue on the specified exchange. When an event message that matches the observer's routing keys
    # is received, parse the event and call handle_event on same.
    # @param [Isimud::Client] client client instance
    # @return queue or consumer object
    # @see BunnyClient#subscribe
    # @see TestClient#subscribe
    def observe_events(client)
      return unless enable_listener?
      queue = create_queue(client)
      client.subscribe(queue) do |message|
        event = Event.parse(message)
        handle_event(event)
      end
    end

    def event_queue_name
      self.class.event_queue_name(id)
    end

    def isimud_client
      Isimud.client
    end

    # Activate the queues for an observer. This will create the observer queue and send an update message on the
    # instance, which will trigger EventListener instances to set up consumers. This is useful for situations when
    # an observer is to be made active without an update.
    def activate_observer(client = isimud_client)
      create_queue(client)
      isimud_send_action_message(:update)
    end

    # Deactivate the queues for an observer. This will destroy the observer queue and send an update message on the
    # instance, which will trigger EventListener instances to cancel consumers. Note that enable_listener? should
    # resolve to false in order for the EventListener to cancel corresponding event consumers.
    def deactivate_observer(client = isimud_client)
      delete_queue(client)
      isimud_send_action_message(:update)
    end

    private

    def create_queue(client = isimud_client)
      exchange = observed_exchange || Isimud.events_exchange
      log "Isimud::EventObserver: creating queue #{event_queue_name} on exchange #{exchange} with bindings [#{exchange_routing_keys.join(',')}]"
      client.create_queue(event_queue_name, exchange, routing_keys: exchange_routing_keys)
    end

    def update_queue
      delete_queue
      create_queue if enable_listener? && exchange_routing_keys.any?
    end

    def delete_queue(client = isimud_client)
      client.delete_queue(event_queue_name)
    end

    def set_routing_keys
      self.exchange_routing_keys = routing_keys
    end

    module ClassMethods
      # Method used to retrieve active observers. Override in your EventObserver class
      def find_active_observers
        []
      end

      def queue_prefix
        Rails.application.class.parent_name.downcase
      end

      def event_queue_name(id)
        [queue_prefix, base_class.name.underscore, id].join('.')
      end

      protected

      def register_class
        Isimud::EventObserver.observed_mutex.synchronize do
          unless Isimud::EventObserver.observed_models.include?(self.base_class)
            Rails.logger.info("Isimud::EventObserver: registering #{self.base_class}")
            Isimud::EventObserver.observed_models << self.base_class
          end
        end
      end
    end
  end
end
