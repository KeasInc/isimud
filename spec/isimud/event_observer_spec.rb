require 'spec_helper'

describe Isimud::EventObserver do
  before do
    Isimud.model_watcher_exchange = 'isimud.test.events'
    @client                       = Isimud.client
  end

  #let(:client) { Isimud.client }
  let(:exchange_name) { 'events' }
  let(:company) { Company.create!(name: 'Keas', description: 'Health Engagement Platform', url: 'http://keas.com') }
  let(:keys) { %w(a.b.c d.*.f) }
  let(:user_params) { {first_name:         'Geo',
                       last_name:          'Feil',
                       encrypted_password: "itsasecret",
                       keys:               keys,
                       email:              'george.feil@keas.com'} }
  let(:time) { 1.hour.ago }
  let(:params) { {'a' => 'foo', 'b' => 123} }

  it 'registers class in observed_models' do
    expect(Isimud::EventObserver.observed_models).to include(User)
  end

  describe 'when created' do
    before do
      @queue    = double(:queue)
      @exchange = Isimud.events_exchange
    end

    it 'creates observer queue' do
      expect(@client).to receive(:find_queue).and_return(@queue)
      keys.each { |key| expect(@queue).to receive(:bind).with(@exchange, routing_key: key) }
      User.create(user_params)
    end

    it 'does not create observer queue when listener is not enabled' do
      expect(@client).not_to receive(:create_queue)
      User.create(user_params.merge(deactivated: true))
    end

    it 'sets exchange_routing_keys' do
      user = User.create(user_params)
      expect(user.exchange_routing_keys).to eql(user.routing_keys)
    end
  end

  describe 'when modified' do
    before do
      @exchange = Isimud.events_exchange
    end

    context 'for an instance that is made active on update' do
      before do
        @user  = User.create(user_params.merge(deactivated: true))
        @queue = @client.find_queue(@user.event_queue_name)
      end

      it 'creates the queue' do
        expect(@client).to receive(:find_queue).with(@user.event_queue_name).and_call_original
        @user.update_attributes(deactivated: false)
      end

      it 'binds the routing keys' do
        @user.exchange_routing_keys.each do |k|
          expect(@queue).to receive(:bind).with(@exchange, routing_key: k).and_call_original
        end
        @user.update_attributes(deactivated: false)
      end
    end

    context 'for an already active instance' do
      before do
        @user  = User.create(user_params)
        @queue = @client.find_queue(@user.event_queue_name)
      end

      it 'binds new keys' do
        @user.exchange_routing_keys.each do |k|
          expect(@queue).to receive(:bind).with(@exchange, routing_key: k).and_call_original
        end
        expect(@queue).to receive(:bind).with(@exchange, routing_key: 'some_other_value').and_call_original
        @user.transaction do
          @user.keys << 'some_other_value'
          @user.save!
        end
      end

      it 'removes old keys' do
        expect(@queue).to receive(:unbind).with(@exchange, routing_key: 'a.b.c')
        expect(@queue).not_to receive(:unbind).with(@exchange, routing_key: 'd.*.f')
        @user.keys.delete('a.b.c')
        @user.save!
      end
    end
  end

  describe 'when destroyed' do
    before do
      @exchange = Isimud.events_exchange
      @user     = User.create(user_params)
    end

    it 'removes the queue' do
      expect(@client).to receive(:delete_queue).with("combustion.user.#{@user.id}")
      @user.destroy
    end
  end

  describe '#observe_events' do
    before do
      @user = User.create(user_params.merge(keys: ['model.Company.*.create']))
      @user.observe_events(@client)
    end

    it 'parses messages and dispatches to the handle_event method' do
      event = Isimud::Event.new(@user, company, exchange: @exchange, action: :create, occurred_at: time, parameters: params)
      event.publish
      expect(@user.events).not_to be_empty
    end
  end

end