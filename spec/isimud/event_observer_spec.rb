require 'spec_helper'

class EventedUser < User
  attr_accessor :events, :routing_keys
  include Isimud::EventObserver

  def handle_event(event)
    self.events ||= Array.new
    self.events << event
  end

  def queue_prefix
    'test'
  end

end

describe Isimud::EventObserver do
  let(:client) { Isimud.client }
  let(:exchange_name) { 'events' }
  let(:user) { User.create!(first_name:         'Geo',
                            last_name:          'Feil',
                            encrypted_password: "itsasecret",
                            email:              'george.feil@keas.com') }
  let!(:eventful) { Company.create!(name: 'Keas', description: 'Health Engagement Platform', url: 'http://keas.com') }
  let(:time) { 1.hour.ago }
  let(:params) { {'a' => 'foo', 'b' => 123} }
  let!(:evented) { EventedUser.create(routing_keys:       ['model.Company.*.create', 'model.Event.*.report']) }
  let(:event) { Isimud::Event.new(user, eventful, action: :create, occurred_at: time, parameters: params) }


  describe '#observe_events' do
    before(:each) do
      evented.observe_events(client, exchange_name)
    end

    it 'binds routing keys to the named queue in the exchange' do
      ap client.queues
      queue = client.queues["test.evented_user.#{evented.id}"]
      expect(queue).to have_matching_key("model.Company.123.create")
    end

    it 'parses messages and dispatches to the handle_event method' do
      event.publish
      expect(evented.events).to include(kind_of(Isimud::Event))
    end
  end

end