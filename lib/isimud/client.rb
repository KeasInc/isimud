module Isimud
  class Client
    def log(message, level = Isimud.log_level)
      Isimud.logger.send (level || :debug).to_sym , message
    end
  end
end

require 'isimud/bunny_client'
require 'isimud/test_client'
