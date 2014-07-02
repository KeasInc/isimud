require 'spec_helper'

describe Isimud::BunnyClient do
  let(:url) { 'amqp://guest:guest@localhost' }
  let(:client) { Isimud::BunnyClient.new(url) }
  let!(:connection) { client.connect }

  after(:each) do
    client.close
  end

  describe '#initialize' do
    it 'sets the broker URL' do
      expect(client.url).to eq(url)
    end
  end

  describe '#connect' do
    it 'returns a Bunny session' do
      expect(connection).to be_a Bunny::Session
    end

    it 'sets the connection' do
      expect(client.connection).to eql(connection)
    end

    it 'reuses an existing connection' do
      connection = client.connection
      expect(client.connect).to eql(connection)
    end

    it 'opens a connection to the broker' do
      connection.should be_open
    end

  end

  describe '#channel' do
    it 'returns a channel' do
      expect(client.channel).to be_a Bunny::Channel
    end

    it 'reuses an open channel' do
      expect(client.channel).to eql(client.channel)
    end

    it 'creates a new channel if the previous one is closed' do
      closed_channel = client.channel.tap(&:close)
      expect(client.channel).not_to eql(closed_channel)
    end

    it 'keeps the channel thread local' do
      channel = client.channel
      t = Thread.new do
        expect(client.channel).not_to eql(channel)
      end
      t.join
    end
  end

  describe '#close' do
    it 'closes the session' do
      client.close
      expect(client.connection).not_to be_open
    end
  end

end