module Isimud
  class BunnyClient
    attr_reader :url, :connection

    def initialize(_url)
      @url = _url
    end

    def connect
      @connection ||= Bunny.new(url).tap(&:start)
    end

    def channel
      if (channel = Thread.current[:'isimud.bunny_client.channel']).try(:open?)
        channel
      else
        Thread.current[:'isimud.bunny_client.channel'] = connection.channel
      end
    end

    def close
      connection.close
    end
  end
end