require 'spec_helper'

describe Isimud::EventListener do
  let!(:company) { Company.create(name: 'Google', active: true) }
  let!(:inactive_company) { Company.create(name: 'Radio Shack', active: false) }
  let!(:listener) { Isimud::EventListener.new(name: 'all_ears', error_limit: 5, exchange: 'test-listener') }

  after(:each) do
    Isimud.client.reset
  end

  describe 'initialization' do
    it 'sets parameters' do
      listener = Isimud::EventListener.new(events_exchange: 'parties',
                                           models_exchange: 'hot_bods',
                                           error_limit:     1,
                                           error_interval:  5.minutes,
                                           name:            'ear')
      expect(listener.events_exchange).to eq('parties')
      expect(listener.models_exchange).to eq('hot_bods')
      expect(listener.error_limit).to eq(1)
      expect(listener.error_interval).to eq(5.minutes)
      expect(listener.name).to eq('ear')
    end

    it 'applies defaults' do
      listener = Isimud::EventListener.new
      expect(listener.events_exchange).to eq('events')
      expect(listener.models_exchange).to eq('models')
      expect(listener.error_limit).to eq(10)
      expect(listener.error_interval).to eq(1.hour)
      expect(listener.name).to eq('combustion-listener')
    end
  end

  describe 'message delivery' do
    before do
      listener.bind_queues
    end

    describe '#bind_queues' do
      it 'registers active observers' do
        expect(listener).to have_observer(company)
      end

      it 'initializes an observer_queue' do
        expect(listener.instance_variable_get(:@observer_queue)).to be_present
      end

      it 'skips inactive observers' do
        expect(listener).not_to have_observer(inactive_company)
      end
    end

    describe 'handling messages' do
      it 'dispatches events to observer' do
        expect {
          User.create!(company: company, first_name: 'Larry', last_name: 'Page')
          company.reload
        }.to change(company, :user_count)
      end
    end

    describe 'handling observer updates' do
      it 'registers a new observer' do
        another_company = Company.create!(name: 'Apple', active: true)
        expect(listener.has_observer?(another_company)).to eql(true)
      end

      it 're-registers an updated observer'

      it 'purges the queue for a deleted observer'
    end

    describe 'handling errors' do
      it 'counts errors'
      it 'triggers a shutdown if errors exceed limit'
    end
  end
end