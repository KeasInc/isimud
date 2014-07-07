require 'spec_helper'

describe Isimud::TestClient do
  let(:client) { Isimud::TestClient.new(url) }
  let!(:connection) { client.connect }

  after(:each) do
    client.close
  end

  describe '#initialize' do
    it 'sets up new queues'
  end

  describe '#bind' do
    let(:proc) { Proc.new { puts('hello') } }
    let(:keys) { %w(foo.bar baz.*) }

    it 'creates a new queue'

    it 'binds specified routing keys and calls the specified method'
  end

  describe '#publish' do
    it 'pushes the data to the appropriate queues'
  end

end