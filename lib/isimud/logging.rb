module Isimud
  module Logging
    def log(message, level = Isimud.log_level)
      logger.send (level || :debug).to_sym , message
    end

    def logger
      Isimud.logger
    end
  end
end