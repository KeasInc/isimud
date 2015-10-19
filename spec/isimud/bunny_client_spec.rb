require 'spec_helper'

describe Isimud::BunnyClient do
  before(:each) do
    @exchange_name = 'isimud_test'
    @url = 'amqp://guest:guest@localhost'
  end

  let!(:client) { Isimud::BunnyClient.new(@url) }
  let!(:connection) { client.connection }

  describe '#initialize' do
    it 'sets the broker URL' do
      expect(client.url).to eq(@url)
    end
  end

  describe '#bind' do
    let(:channel) { client.channel }
    let(:proc) { Proc.new { puts('hello') } }
    let(:keys) { %w(foo.bar baz.*) }
    let(:queue_name) { 'my_queue' }
    before do
      Isimud.logger = Logger.new(STDOUT)
    end
    after do
      client.delete_queue(queue_name)
    end


    it 'creates a new queue' do
      consumer = client.bind('my_queue', @exchange_name, keys, &proc)
      expect(consumer).to be_a Bunny::Consumer
      expect(consumer.queue_name).to eq('my_queue')
    end

    context 'when a block is passed to the call' do
      it 'binds specified routing keys and subscribes to the specified exchange' do
        queue = double('queue', name: 'my_queue', bind: 'ok')
        expect(client).to receive(:find_queue).with('my_queue', durable: true).and_return(queue)
        expect(queue).to receive(:subscribe).with({manual_ack: true})
        keys.each { |key| expect(queue).to receive(:bind).with(@exchange_name, routing_key: key, nowait: false).once }
        client.bind('my_queue', @exchange_name, *keys, &proc)
      end
    end

    context 'when a block is NOT passed' do
      it 'binds specified routing keys BUT does not subscribes to the specified exchange' do
        queue = double('queue', name: 'my_queue', bind: 'ok')
        expect(client).to receive(:find_queue).with('my_queue', durable: true).and_return(queue)
        expect(queue).not_to receive(:subscribe).with(manual_ack: true)
        keys.each { |key| expect(queue).to receive(:bind).with(@exchange_name, routing_key: key, nowait: false).once }
        client.bind('my_queue', @exchange_name, *keys)
      end
    end

    it 'calls block when a message is received' do
      @block_called = Array.new
      queue_name    = 'test_queue'
      client.bind("#{queue_name}", @exchange_name, 'my.test.key') do |payload|
        @block_called << payload
      end
      client.publish(@exchange_name, 'my.test.key', "Hi there")
      sleep(1)
      expect(@block_called).to eq ['Hi there']
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
      expect(connection).to be_open
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

    it 'enables confirmations' do
      channel = client.channel
      expect(channel.next_publish_seq_no).to eq(1)
    end

    it 'keeps the channel thread local' do
      channel = client.channel
      t       = Thread.new do
        expect(client.channel).not_to eql(channel)
      end
      t.join
    end
  end

  describe '#connected?' do
    it 'is true for an open session' do
      expect(client).to be_connected
    end

    it 'is false for a closed session' do
      client.close
      expect(client).not_to be_connected
    end
  end

  describe '#close' do
    it 'closes the session' do
      connection = client.connection
      client.close
      expect(connection).not_to be_open
    end
  end

  describe '#publish' do
    let(:channel) { client.channel }
    it 'sends the data with the appropriate routing key to the exchange' do
      payload = {a: '123', b: 'this is b'}
      topic   = double(:topic)
      expect(channel).to receive(:topic).with(@exchange_name, durable: true).and_return(topic)
      expect(topic).to receive(:publish).with(payload, routing_key: 'foo.bar.baz', persistent: true)
      client.publish(@exchange_name, 'foo.bar.baz', payload)
    end
  end

end