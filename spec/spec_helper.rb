require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'rubygems'
require 'bundler/setup'
require 'isimud'

require 'combustion'

Combustion.initialize! :active_record

require 'rspec/rails'

Isimud.client_type = :test
Isimud.logger = Rails.logger

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
end
