require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'rubygems'
require 'bundler/setup'
require 'isimud'

require 'combustion'
require 'database_cleaner'

Isimud.client_type = :test
Isimud.logger = Logger.new(STDOUT)
Isimud.logger.level = Logger::DEBUG
Isimud.log_level = :debug
Isimud.listener_error_limit = 50
Isimud.enable_model_watcher = true
Isimud.model_watcher_exchange = 'isimud.test.events'
Isimud.model_watcher_schema = 'test_schema'
Isimud::EventObserver.observed_models = Array.new
Isimud::EventObserver.observed_mutex = Mutex.new
Combustion.initialize! :active_record

puts "database configuration: "

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    # be_bigger_than(2).and_smaller_than(4).description
    #   # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #   # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

