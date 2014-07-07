require 'spec_helper'

describe Isimud::BunnyClient do
  let(:url) { 'amqp://guest:guest@localhost' }
  let(:client) { Isimud::BunnyClient.new(url) }
  let!(:connection) { client.connection }

  after(:each) do
    client.close
  end

  describe '#initialize' do
    it 'sets the broker URL' do
      expect(client.url).to eq(url)
    end
  end

  describe '#bind' do
    let(:channel) { client.channel }
    let(:proc) { Proc.new { puts('hello') } }
    let(:keys) { %w(foo.bar baz.*) }

    it 'creates a new queue' do
      queue = client.bind('my_queue', 'events', keys, &proc)
      expect(queue).to be_a Bunny::Queue
      expect(queue.name).to eq('my_queue')
    end

    it 'binds specified routing keys and subscribes to the specified exchange' do
      queue = double('queue', bind: 'ok')
      channel.stub(:queue).and_return(queue)
      expect(queue).to receive(:subscribe).with(ack: true)
      keys.each { |key| expect(queue).to receive(:bind).with('events', routing_key: key, nowait: false).once }
      client.bind('my_queue', 'events', *keys, proc)
    end
  end

  describe '#connection' do
    it 'returns a Bunny session' do
      expect(connection).to be_a Bunny::Session
    end

    it 'sets and reuses the connection' do
      connection = client.connection
      expect(client.connection).to eql(connection)
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
      t       = Thread.new do
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

  describe '#publish' do
    let(:channel) { client.channel }
    it 'sends the data with the appropriate routing key to the exchange' do
      payload = {a: '123', b: 'this is b'}
      topic   = double(:topic)
      expect(channel).to receive(:topic).with('events', durable: true).and_return(topic)
      expect(topic).to receive(:publish).with(payload, routing_key: 'foo.bar.baz', persistent: true)
      client.publish('events', 'foo.bar.baz', payload)
    end
  end

end