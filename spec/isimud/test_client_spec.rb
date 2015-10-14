require 'spec_helper'

describe Isimud::TestClient do
  let(:client) { Isimud::TestClient.new }
  let!(:connection) { client.connect }
  let!(:keys) { %w(foo.bar baz.*.argle) }

  before(:each) do
    @called = false
    @proc = Proc.new { @called = true }
  end

  after(:each) do
    client.close
  end

  describe '#initialize' do
    it 'sets up an empty set of queues' do
      expect( client.queues ).to be_empty
    end
  end

  describe 'queues and bindings' do
    before do
      client.bind('queue_name', 'exchange_name', *keys, &@proc)
    end
    let!(:queue) { client.find_queue('queue_name') }

    it 'binds routing keys to the queue' do
      expect( queue.bindings ).to eql('exchange_name' => Set.new(keys))
    end

    it 'removes a binding from the queue' do
      queue.unbind('exchange_name', routing_key: 'foo.bar')
      expect( queue.bindings ).to eql('exchange_name' => Set.new(['baz.*.argle']))
    end
  end

  describe '#unbind' do
    before do
      client.bind('queue_name', 'exchange_name', *keys, &@proc)
    end
  end

  describe '#publish' do
    before do
      @dont_call = false
      @dont_call_proc = Proc.new { @dont_call = true }
      client.bind('queue_name', 'exchange_name', *keys, &@proc)
      client.bind('other_queue', 'exchange_name', 'no.match.*', &@dont_call_proc)
      client.publish('exchange_name', 'baz.1.argle', {abc: 'do re me'})
    end

    it 'calls proc for the matching queue' do
      expect(@called).to be_truthy
    end

    it 'does not call proc for non matching queue' do
      expect(@dont_call).to be_falsey
    end
  end

end