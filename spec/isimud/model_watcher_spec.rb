require 'spec_helper'

describe ModelWatcher do

  let(:channel) { ModelWatcher::BunnyAmqp.channel }
  let(:queue) { channel.queue("users", :auto_delete => true) }
  let(:exchange) { channel.default_exchange }

  before do
    queue.subscribe do |delivery_info, metadata, payload|
      @result = payload
    end
  end

  def result
    seconds_to_wait_for_result = 0.2
    Timeout::timeout(seconds_to_wait_for_result) do
      until defined?(@result)
        sleep 0.01
      end
      return @result
    end
  rescue Timeout::Error
    raise "Message didn't show up within #{seconds_to_wait_for_result} seconds."
  end

  context 'when a watched model is created' do
    let!(:user) { User.create!(email: 'bob@example.com') }

    it "sends messages about model creation" do
      expect(result).to eq(user.to_json)
    end
  end

end

