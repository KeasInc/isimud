require 'isimud'
require 'thread'

module Isimud
  class EventListener
    include Logging
    attr_reader :error_count, :error_interval, :error_limit, :name, :queues, :events_exchange, :models_exchange,
                :running

    DEFAULT_ERROR_LIMIT    = 10
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
      @error_count         = 0
      @observers           = Hash.new
      @observed_models     = Set.new
      @error_limit         = options[:error_limit]
      @error_interval      = options[:error_interval]
      @events_exchange     = options[:events_exchange]
      @models_exchange     = options[:models_exchange]
      @name                = options[:name]
      @observer_mutex      = Mutex.new
      @error_counter_mutex = Mutex.new
      @running             = false
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
      client.on_exception do |e|
        count_error(e)
      end
      client.connect
      start_event_thread

      puts 'EventListener started. Hit Ctrl-C to exit'
      Thread.stop
      puts 'Main thread wakeup - exiting.'
      client.close
    end

    # Override this method to set up message observers
    def bind_queues
      Isimud::EventObserver.observed_models.each do |model_class|
        log "EventListener: registering observers for #{model_class}"
        register_observer_class(model_class)
        count = 0
        model_class.find_active_observers.each do |model|
          register_observer(model)
          count += 1
        end
        log "EventListener: registered #{count} observers for #{model_class}"
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
      %w(SIGINT SIGTERM).each { |sig| trap(sig) { shutdown_thread.wakeup } }
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
            Rails.logger.info 'EventListener: event_thread finished'
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
      @error_counter_mutex.synchronize do
        @error_count += 1
        log "EventListener#count_error count = #{@error_count} limit=#{error_limit}", :warn
        if (@error_count >= error_limit)
          log 'EventListener: too many errors, exiting', :fatal
          @running = false
          Thread.main.run unless test_env?
        end
      end
    end

    # start an error counter thread that clears the error count once per hour
    def start_error_counter_thread
      log 'EventListener: starting error counter'
      @error_count = 0
      Thread.new do
        while true
          sleep(error_interval)
          @error_counter_mutex.synchronize do
            log('EventListener: resetting error counter') if @error_count > 0
            @error_count = 0
          end
        end
      end
    end

    def handle_observer_event(payload)
      event = JSON.parse(payload).with_indifferent_access
      action = event[:action]
      log "EventListener: received observer model message: #{event.inspect}"
      observer = event[:type].constantize.find(event[:id]) unless action == 'destroy'
      case
        when action == 'create'
          register_observer(observer) if observer.enable_listener?
        when action == 'update' && observer.enable_listener?
          rebind_observer(observer)
        else
          unregister_observer(event[:type], event[:id])
      end
    end

    # Create and bind a queue for the observer. Also ensure that we are listening for observer class update events
    def register_observer(observer)
      @observer_mutex.synchronize do
        log "EventListener: registering observer #{observer.class} #{observer.id}"
        observer.observe_events(client, events_exchange)
        @observers[observer_key_for(observer.class, observer.id)] = observer
      end
    end

    # Update the bindings for an observer.
    def rebind_observer(observer)
      log "EventListener: rebinding observer #{observer.class} #{observer.id}"
      #client.rebind(observer.event_queue_name, events_exchange, observer.routing_keys)
    end

    # Delete a queue for an observer. This also purges all messages associated with it
    def unregister_observer(observer_class, observer_id)
      @observer_mutex.synchronize do
        log "EventListener: un-registering observer #{observer_class} #{observer_id}"
        queue_name = observer_class.constantize.event_queue_name(observer_id)
        client.delete_queue(queue_name)
        @observers.delete(observer_key_for(observer_class, observer_id))
      end
    end

    # Create or return the observer queue which listens for ModelWatcher events
    def observer_queue
      @observer_queue ||= client.create_queue("#{name}.listener", models_exchange, &method(:handle_observer_event))
    end

    # Register the observer class watcher
    def register_observer_class(observer_class)
      @observer_mutex.synchronize do
        return if @observed_models.include?(observer_class)
        @observed_models << observer_class
        log "EventListener: registering observer class #{observer_class}"
        observer_queue.bind(models_exchange, "#{Isimud.model_watcher_schema}.#{observer_class.base_class.name}.*")
      end
    end

    def observer_key_for(type, id)
      [type.to_s, id.to_s].join(':')
    end
  end
end


