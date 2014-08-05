module Isimud
  class Client
    include Isimud::Logging
  end
end

require 'isimud/bunny_client'
require 'isimud/test_client'
