require 'spec_helper'

describe Isimud::ModelWatcher do
  let(:client) { Isimud.client }
  let(:company) { Company.create!(name: 'Keas Inc', url: 'http://keas.com') }

  describe '.watch_attributes' do
    context 'default' do
      it 'returns the data attributes, minus the id and timestamps' do
        expect(Company.isimud_watch_attributes).to eq([:name, :description, :url])
      end
    end

    context 'when assigned' do
      it 'assigns the watch attributes appropriately' do
        # User: watch_attributes :key, :login_count
        expect(User.isimud_watch_attributes).to eq([:key, :login_count])
      end
    end

    context 'for a subclass' do
      it 'uses the watch attributes for the superclass' do
        expect(Admin.isimud_watch_attributes).to eq([:key, :login_count])
      end
    end
  end

  describe 'when creating an instance' do
    it 'sends a create message' do
      Timecop.freeze do
        user = User.new(first_name:         'Geo',
                        last_name:          'Feil',
                        encrypted_password: "itsasecret",
                        email:              'george.feil@keas.com')


        messages    = Array.new
        exchange    = Isimud::ModelWatcher::DEFAULT_EXCHANGE
        routing_key = 'db/combustion_test.sqlite.User.create'

        Isimud.client.bind('model_watcher_spec_create', exchange, routing_key) do |payload|
          messages << payload
        end
        user.save!
        expect(messages).to include(expected_user_payload(user, :create))
      end
    end
  end

  describe '#isimud_synchronize?' do
    it "doesn't send a message when false" do
      user = User.new(first_name:         'Geo',
                      last_name:          'Feil',
                      encrypted_password: "itsasecret",
                      email:              'george.feil@keas.com')
      user.stub(:isimud_synchronize?).and_return(false)
      messages    = Array.new
      Isimud.client.bind('model_watcher_spec_create', Isimud::ModelWatcher::DEFAULT_EXCHANGE, '*') do |payload|
        messages << payload
      end
      user.save!
      expect(messages).to be_empty
    end
  end

  describe 'when disabled' do
    before do
      Isimud.enable_model_watcher = false
    end
    after do
      Isimud.enable_model_watcher = nil
    end

    it 'does not send a message' do
      messages = Array.new
      Isimud.client.bind('model_watcher_spec_create', Isimud::ModelWatcher::DEFAULT_EXCHANGE, '*') do |payload|
        messages << payload
      end
      User.create!(first_name:         'Geo',
                   last_name:          'Feil',
                   encrypted_password: "itsasecret",
                   email:              'george.feil@keas.com')
      expect(messages).to be_empty
    end

  end

  describe 'when updating an instance' do
    before(:all) do
      @messages = Array.new
      Isimud.client.bind('model_watcher_spec_update',
                         Isimud::ModelWatcher::DEFAULT_EXCHANGE,
                         'db/combustion_test.sqlite.User.update') do |payload|
        @messages << payload
      end
    end
    before(:each) do
      @messages.clear
    end

    let!(:user) { User.create!(first_name:         'Geo',
                               last_name:          'Feil',
                               encrypted_password: "itsasecret",
                               email:              'george.feil@keas.com') }


    context 'with a watched attribute updated' do
      it 'sends a message with the update' do
        Timecop.freeze do
          user.login_count = 1
          user.save!
          expect(@messages).to include(expected_user_payload(user, :update))
        end
      end

      context 'with no watched attributes updated' do
        it 'sends no messages' do
          user.first_name = 'Hal'
          user.save!
          expect(@messages).to be_empty
        end
      end

    end
  end

  describe 'when destroying an instance' do
    before(:all) do
      @messages = Array.new
      Isimud.client.bind('model_watcher_spec_destroy',
                         Isimud::ModelWatcher::DEFAULT_EXCHANGE,
                         'db/combustion_test.sqlite.User.destroy') do |payload|
        @messages << payload
      end
    end
    before(:each) do
      @messages.clear
    end

    let!(:user) { User.create!(first_name:         'Geo',
                               last_name:          'Feil',
                               encrypted_password: "itsasecret",
                               email:              'george.feil@keas.com') }
    it 'sends a destroy message' do
      Timecop.freeze do
        user.destroy
        expected_message = {schema:    'db/combustion_test.sqlite',
                            type:      'User',
                            action:    :destroy,
                            id:        user.id,
                            timestamp: Time.now.utc}.to_json
        expect(@messages).to include(expected_message)
      end
    end
  end

  private

  def expected_user_payload(user, action)
    {
        :schema     => "db/combustion_test.sqlite",
        :type       => "User",
        :action     => action,
        :id         => user.id,
        :timestamp  => Time.now.utc,
        :attributes => {:key => user.key, :login_count => user.login_count}
    }.to_json
  end

end

