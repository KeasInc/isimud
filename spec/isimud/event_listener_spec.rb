require 'spec_helper'

describe Isimud::EventListener do
  before do
    @company = Company.create(name: 'Google', active: true)
    @listener = Isimud::EventListener.new(name: 'all_ears', error_limit: 5, exchange: 'test-listener')
  end

  let!(:company) { @company }
  let!(:inactive_company) { Company.create(name: 'Radio Shack', active: false) }
  let!(:listener) { @listener }

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
      expect(listener.models_exchange).to eq('isimud.test.events')
      expect(listener.error_limit).to eq(50)
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

    describe '#handle_observer_event' do
      context 'handling observer destroy messages' do
        it 'purges the queue for a destroy observer' do
          expect(listener).to have_observer(company)
          company.destroy
          expect(listener).not_to have_observer(company)
        end
      end

      context 'handling new observer messages' do
        it 'registers a new observer' do
          another_company = Company.create!(name: 'Apple', active: true)
          expect(listener).to have_observer(another_company)
        end

        it 'does not register an observer when listening is disabled' do
          another_company = Company.create!(name: 'Apple', active: false)
          expect(listener).not_to have_observer(another_company)
        end
      end

      context 'handling observer update messages' do
        it 'reloads the observer and processes events accordingly' do
          expect(listener).to receive(:unregister_observer).with('Company', company.id).and_call_original
          expect(listener).to receive(:register_observer).with an_instance_of(Company)
          company.update_attributes!(points_per_user: 2)
        end
      end

      context 'handling messages' do
        it 'dispatches events to observer' do
          expect {
            User.create!(company: company, first_name: 'Larry', last_name: 'Page')
            company.reload
          }.to change(company, :user_count)
        end
      end
    end

    describe 'handling errors' do
      before do
        @some_company = Company.create!(name: 'Apple', active: true)
      end
      xit 'counts errors' do
        # Verify that the listener's error count starts from zero
        expect(listener.error_count).to eql 0

        # Verify that the listener's error count increased to one with the first new exception
        # Verify that the listener's error count increased to two with the second new exception
      end
      xit 'triggers a shutdown if errors exceed limit' do
        # Verify that the listener shuts down / stops listening when the threshold is exceeded
      end
    end
  end
end