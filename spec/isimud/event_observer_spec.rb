require 'spec_helper'

describe Isimud::EventObserver do
  before do
    Isimud.model_watcher_exchange = 'isimud.test.events'
    @client                       = Isimud.client
  end

  #let(:client) { Isimud.client }
  let(:exchange_name) { 'events' }
  let(:company) { Company.create!(name: 'Keas', description: 'Health Engagement Platform', url: 'http://keas.com') }
  let(:user_params) { {first_name:         'Geo',
                       last_name:          'Feil',
                       encrypted_password: "itsasecret",
                       keys:               %w(a.b.c d.*.f),
                       email:              'george.feil@keas.com'} }
  let(:time) { 1.hour.ago }
  let(:params) { {'a' => 'foo', 'b' => 123} }

  it 'registers class in observed_models' do
    expect(Isimud::EventObserver.observed_models).to include(User)
  end

  describe 'when created' do
    before do
      @queue = double(:queue)
      @exchange = Isimud.events_exchange
    end

    it 'creates observer queue' do
      expect(@client).to receive(:find_queue).and_return(@queue)
      expect(@queue).to receive(:bind).with(@exchange, 'a.b.c')
      expect(@queue).to receive(:bind).with(@exchange, 'd.*.f')
      User.create(user_params)
    end

    it 'sets exchange_routing_keys' do
      user = User.create(user_params)
      expect(user.exchange_routing_keys).to eql(user.routing_keys)
    end
  end

  describe 'when modified' do
    before do
      @queue = double(:queue)
      @exchange = Isimud.events_exchange
      @user = User.create( user_params )
    end
    context 'when the change does not affect the routing keys' do
      before do
        expect(@client).not_to receive(:find_queue)
      end
      it 'should NOT touch the queue called' do
        @user.update_attributes({:first_name =>'bettar name'})
      end
    end

    context 'when the change does affect the routing keys' do
      before do
        expect(@client).to receive(:find_queue).and_return(@queue)
      end

      it 'binds new keys' do
        @user.keys << 'some_other_value'
        expect(@queue).to receive(:bind).with(@exchange, 'some_other_value')
        expect(@queue).not_to receive(:bind).with(@exchange, 'a.b.c')
        @user.save
      end

      it 'removes old keys' do
        @user.keys.delete('a.b.c')
        expect(@queue).to receive(:unbind).with(@exchange, 'a.b.c')
        expect(@queue).not_to receive(:unbind).with(@exchange, 'd.*.f')
        @user.save
      end
    end
  end

  describe 'when destroyed' do
    before do
      @exchange = Isimud.events_exchange
      @user = User.create( user_params )
    end

    it 'removes the queue' do
      expect(@client).to receive(:delete_queue).with("combustion.user.#{@user.id}")
      @user.destroy
    end
  end

  describe '#observe_events' do
    before do
      @user = User.create( user_params.merge(keys: ['model.Company.*.create']))
      @user.observe_events(@client, @exchange)
    end

    it 'parses messages and dispatches to the handle_event method' do
      event = Isimud::Event.new(@user, company, exchange: @exchange, action: :create, occurred_at: time, parameters: params)
      event.publish
      expect(@user.events).not_to be_empty
    end
  end

end