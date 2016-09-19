require 'active_support'

module Isimud
  # A structured message format useful for processing events.
  # Note that each message has a routing key automatically constructed based on four properties:
  # type.eventful_type.eventful_id.action
  # Any blank or nil properties are omitted from the routing key.
  # For convenience, you may construct an event using an eventful object, which sets the eventful_type and eventful_id
  class Event
    include Isimud::Logging
    attr_accessor :type, :action, :user_id, :occurred_at, :eventful_type, :eventful_id, :attributes, :parameters
    attr_reader :timestamp
    attr_writer :exchange

    DEFAULT_TYPE = :model

    # Initialize a new Event.
    # @overload new(user, eventful, attributes)
    #   @param[#id] user user associated by the event
    #   @param[ActiveRecord::Base] eventful object associated with event
    #   @param[Hash] parameters optional additional attributes
    # @overload new(attributes)
    #   @param[Hash] attributes event attributes
    #   @option attributes [Integer] :user_id ID of User associated with event
    #   @option attributes [String] :eventful_type type of object associated with event
    #   @option attributes [Integer] :eventful_id id of object associated with event
    #   @option attributes [String] :exchange (Isimud.events_exchange) exchange for publishing event
    #   @option attributes [#id] :eventful object associated with event. This sets :eventful_type and :eventful_id based
    #     on the class and ID of the object.
    #   @option attributes [String, Symbol] :type (:model) event type
    #   @option attributes [String, Symbol] :action event action
    #   @option attributes [Time] :occurred_at (Time.now) date and time event occurred
    #   @option attributes [Hash] :attributes event attributes
    #   @option attributes [Hash] :parameters additional parameters (deprecated)
    def initialize(*args)
      options = args.extract_options!.with_indifferent_access

      self.type        = options.delete(:type).try(:to_sym) || DEFAULT_TYPE
      self.exchange    = options.delete(:exchange)
      self.action      = options.delete(:action).try(:to_sym)
      self.user_id     = options.delete(:user_id)
      self.occurred_at = if (occurred = options.delete(:occurred_at))
                           occurred.kind_of?(String) ? Time.parse(occurred) : occurred
                         else
                           Time.now.utc
                         end
      @timestamp       = Time.now

      eventful_object = options.delete(:eventful)

      if args.length > 0
        self.parameters = options
        if (user = args.shift)
          self.user_id = user.id
        end
        eventful_object ||= args.shift
      end

      if eventful_object
        self.eventful_type = eventful_object.class.base_class.name
        self.eventful_id   = eventful_object.id
      else
        self.eventful_type = options.delete(:eventful_type)
        self.eventful_id   = options.delete(:eventful_id)
      end
      self.attributes = options.delete(:attributes)
      self.parameters = options.delete(:parameters) || options
    end

    def exchange
      @exchange || Isimud.events_exchange
    end

    def routing_key
      [type.to_s, eventful_type, eventful_id, action].compact.join('.')
    end

    # Message ID, which is generated from the exchange, routing_key, user_id, and timestamp. This is practically
    # guaranteed to be unique across all publishers.
    def message_id
      [exchange, routing_key, user_id, timestamp.to_i, timestamp.nsec].join(':')
    end

    # Return hash of data to be serialized to JSON
    # @option options [Boolean] :omit_parameters when set, do not include attributes or parameters in data
    # @return [Hash] data to serialize
    def as_json(options = {})
      session_id = parameters.delete(:session_id) || Thread.current[:keas_session_id]

      data = {type:          type,
              action:        action,
              user_id:       user_id,
              occurred_at:   occurred_at,
              eventful_type: eventful_type,
              eventful_id:   eventful_id,
              session_id:    session_id}
      unless options[:omit_parameters]
        data[:parameters] = parameters
        data[:attributes] = attributes
      end
      data
    end

    def serialize
      self.to_json
    end

    class << self
      def parse(data)
        Event.new(JSON.parse(data))
      end

      def publish(*args)
        Event.new(*args).publish
      end

      alias_method :dispatch, :publish
    end

    def publish
      data = self.serialize
      log "Event#publish: exchange #{exchange} message_id=#{message_id}"
      Isimud.client.publish(exchange, routing_key, data, message_id: message_id)
    end
  end
end
