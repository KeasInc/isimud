module Isimud
  module Logging
    def log(message, level = Isimud.log_level)
      Isimud.logger.send (level || :debug).to_sym , message
    end
  end
end