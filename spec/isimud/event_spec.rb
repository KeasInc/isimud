require 'spec_helper'

describe Isimud::Event do
  let(:user) { User.create!(first_name:         'Geo',
                            last_name:          'Feil',
                            encrypted_password: "itsasecret",
                            email:              'george.feil@keas.com') }
  let(:eventful) { Company.create!(name: 'Keas', description: 'Health Engagement Platform', url: 'http://keas.com') }
  let(:time) { 1.hour.ago }
  let(:params) { {'a' => 'foo', 'b' => 123} }

  describe 'initialization' do
    it 'initializes with a User, Eventful, and parameters' do
      event = Isimud::Event.new(user, eventful, action: :create, occurred_at: time, parameters: params)
      expect(event.user_id).to eq(user.id)
      expect(event.type).to eq(:model)
      expect(event.occurred_at).to eq(time)
      expect(event.eventful_type).to eq(eventful.class.name)
      expect(event.eventful_id).to eq(eventful.id)
      expect(event.action).to eq(:create)
      expect(event.parameters).to eq(params)
    end

    it 'initializes with an attributes Hash' do
      event = Isimud::Event.new(user_id: user.id, eventful: eventful, action: :create, occurred_at: time,
                                parameters: params)
      expect(event.user_id).to eq(user.id)
      expect(event.type).to eq(:model)
      expect(event.occurred_at).to eq(time)
      expect(event.eventful_type).to eq(eventful.class.name)
      expect(event.eventful_id).to eq(eventful.id)
      expect(event.action).to eq(:create)
      expect(event.parameters).to eq(params)
    end

    it 'parses time strings' do
      now = Time.now
      time = now.to_s
      event = Isimud::Event.new(occurred_at: time)
      expect(event.occurred_at.to_i).to eq(now.to_i)
    end

    it 'sets occurred_at to now by default' do
      Timecop.freeze do
        event = Isimud::Event.new
        expect(event.occurred_at).to eq(Time.now)
      end
    end

    it 'sets type to model by default' do
      event = Isimud::Event.new
      expect(event.type).to eq(:model)
    end
  end

  describe '#routing_key' do
    it 'composes a key from the eventful and action' do
      event = Isimud::Event.new(eventful: eventful, action: 'create')
      expect(event.routing_key).to eq("model.Company.#{eventful.id}.create")
    end

    it 'handles null' do
      event = Isimud::Event.new(eventful_type: 'Mission', action: 'intake')
      expect(event.routing_key).to eq('model.Mission.intake')
    end
  end

end