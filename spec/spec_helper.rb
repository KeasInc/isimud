require 'rubygems'
require 'bundler/setup'
require 'isimud'

require 'combustion'

Combustion.initialize! :active_record

require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end

