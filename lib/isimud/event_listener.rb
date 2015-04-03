require 'isimud'
require 'thread'

module Isimud
  class EventListener
    include Logging
    attr_reader :error_count, :error_interval, :error_limit, :name, :queues, :events_exchange, :models_exchange,
                :running

    DEFAULT_ERROR_LIMIT = 100
    DEFAULT_ERROR_INTERVAL = 3600

    DEFAULT_EVENTS_EXCHANGE = 'events'
    DEFAULT_MODELS_EXCHANGE = 'models'

    def initialize(options = {})
      default_options = {
          error_limit:     Isimud.listener_error_limit || DEFAULT_ERROR_LIMIT,
          error_interval:  DEFAULT_ERROR_INTERVAL,
          events_exchange: Isimud.events_exchange || DEFAULT_EVENTS_EXCHANGE,
          models_exchange: Isimud.model_watcher_exchange || DEFAULT_MODELS_EXCHANGE,
          name:            "#{Rails.application.class.parent_name.downcase}-listener"
      }
      options.reverse_merge!(default_options)
      @error_count     = 0
      @observers       = Hash.new
      @observed_models = Set.new
      @events_exchange = options[:events_exchange] || DEFAULT_EVENTS_EXCHANGE
      @models_exchange = options[:models_exchange] || DEFAULT_MODELS_EXCHANGE
      @error_limit     = options[:error_limit] || DEFAULT_ERROR_LIMIT
      @error_interval  = options[:error_interval] || DEFAULT_ERROR_INTERVAL
      @name            = options[:name]
      @observer_mutex  = Mutex.new
      @running         = false
    end

    def max_errors
      Isimud.listener_error_limit || DEFAULT_ERROR_LIMIT
    end

    def test_env?
      ['cucumber', 'test'].include?(Rails.env)
    end

    def run
      @running = true
      bind_queues and return if test_env?
      start_shutdown_thread
      start_error_counter_thread
      client.connect
      client.exception_handler(&method(:count_error))
      start_event_thread

      puts 'EventListener started. Hit Ctrl-C to exit'
      Thread.stop
      puts 'Exiting.'
      client.close
    end

    # Override this method to set up message observers
    def bind_queues
      EventObserver.observed_models.each do |model_class|
        model_class.find_active_observers.each do |model|
          register_observer(model)
        end
      end
    end

    def has_observer?(observer)
      @observers.has_key?(observer_key_for(observer.class, observer.id))
    end


    private

    def start_shutdown_thread
      shutdown_thread = Thread.new do
        Thread.stop # wait until we get a TERM or INT signal.
        log 'EventListener: shutdown requested.  Shutting down AMQP...', :info
        @running = false
        Thread.main.run
      end
      %w(INT TERM).each { |sig| trap(sig) { shutdown_thread.wakeup } }
    end

    def client
      Isimud.client
    end

    def start_event_thread
      Thread.new do
        log 'EventListener: starting event_thread'
        while @running
          begin
            bind_queues
            Thread.stop
          rescue Bunny::Exception => e
            count_error(e)
            Rails.logger.warn 'EventListener: resetting queues'
            client.reset
          end
        end
      end
    end

    def count_error(exception)
      @error_count += 1
      log "EventListsner: caught error #{exception.inspect}, count = #{@error_count}", :warn
      if (@error_count > error_limit) && @running
        log 'EventListener: too many errors, exiting', :fatal
        @running = false
        Thread.main.wakeup unless test_env?
      end
    end

    # start an error counter thread that clears the error count once per hour
    def start_error_counter_thread
      log 'EventListener: starting error counter'
      @error_count = 0
      Thread.new do
        while true
          sleep(error_interval)
          log 'EventListener: resetting error counter'
          @error_count = 0
        end
      end
    end

    def handle_observer_event(payload)
      event = JSON.parse(payload).with_indifferent_access
      log "EventListener: received observer model message: #{payload.inspect}"
      if %w(update destroy).include?(event[:action])
        unregister_observer(event[:type], event[:id])
      end
      unless event[:action] == 'destroy'
        observer = event[:type].constantize.find(event[:id])
        register_observer(observer)
      end
    end

    # Create and bind a queue for the observer. Also ensure that we are listening for observer class update events
    def register_observer(observer)
      register_observer_class(observer.class)
      @observer_mutex.synchronize do
        log "EventListener: registering observer #{observer.class} #{observer.id}"
        observer.observe_events(client, events_exchange)
        @observers[observer_key_for(observer.class, observer.id)] = observer
      end
    end

    # Delete a queue for an observer. This also purges all messages associated with it
    def unregister_observer(observer_class, observer_id)
      @observer_mutex.synchronize do
        if (observer = @observers.delete(observer_key_for(observer_class, observer_id)))
          begin
            log "EventListener: unregistering #{observer.class} #{observer.id}"
            queue_name = observer_class.constantize.event_queue_name(observer_id)
            client.delete_queue(queue_name)
          rescue => e
            log "EventListener: error unregistering #{observer_class} #{observer_id}: #{e.message}", :warn
          end
        end
      end
    end

    # Create or return the observer queue which listens for ModelWatcher events
    def observer_queue
      @observer_queue ||= client.create_queue("", Isimud.model_watcher_exchange,
                                               queue_options:     {exclusive: true},
                                               subscribe_options: {manual_ack: true}, &method(:handle_observer_event))
    end

    # Register the observer class watcher
    def register_observer_class(observer_class)
      @observer_mutex.synchronize do
        return if @observed_models.include?(observer_class)
        @observed_models << observer_class
        log "EventListener: registering observer class #{observer_class}"
        observer_queue.bind(Isimud.model_watcher_exchange, routing_key: "#{Isimud.model_watcher_schema}.#{observer_class.base_class.name}.*")
      end
    end

    def observer_key_for(type, id)
      [type.to_s, id.to_s].join(':')
    end
  end
end


