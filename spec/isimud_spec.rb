require 'spec_helper'

describe Isimud do
  before(:each) do
    Isimud.default_client = nil
  end

  describe '.client' do
    context 'for test configuration' do
      before do
        Isimud.client_type = :test
      end

      it 'creates a new TestClient client' do
        expect( Isimud.client ).to be_a Isimud::TestClient
      end
    end

    context 'for a remote Bunny server' do
      let(:server_url) { 'amqp://guest:guest@example.com' }
      before do
        Isimud.server      = server_url
        Isimud.client_type = :bunny
      end

      it 'creates a new Isimud::BunnyClient for the specified server' do
        client = Isimud.client
        expect(client).to be_a Isimud::BunnyClient
        expect(client.url).to eql(server_url)
      end
    end
  end

  describe '.model_watcher_enabled?' do
    it 'is true by default' do
      expect(Isimud).to be_model_watcher_enabled
    end

    it 'is true if enable_model_watcher is explicitly set' do
      Isimud.enable_model_watcher = true
      expect(Isimud).to be_model_watcher_enabled
    end

    it 'is false if enable_model_watcher is set to false' do
      Isimud.enable_model_watcher = false
      expect(Isimud).to_not be_model_watcher_enabled
    end
  end
end