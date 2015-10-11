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
      client.queues.should be_empty
    end
  end

  describe '#bind' do
    before do
      client.bind('queue_name', 'exchange_name', *keys, &@proc)
    end

    it 'creates a new queue' do
      client.queues['queue_name'].should be_present
    end

    it 'binds specified routing keys' do
      q = client.queues['queue_name']
      q.routing_keys.should include(/\Aexchange_name:foo\.bar\Z/, /\Aexchange_name:baz\..*\.argle\Z/)
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