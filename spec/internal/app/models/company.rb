require_relative "../../../../lib/isimud"

class Company < ActiveRecord::Base
  include Isimud::EventObserver

  has_many :users

  def self.find_active_observers
    where(active: true).all
  end

  def routing_keys
    ["*.*.User.create", "*.*.User.destroy"]
  end

  def handle_event(event)
    user = User.find(event.parameters[:id])
    return unless user.company_id == id
    case event.action.to_s
      when 'create'
        reload
        update_attribute(:user_count, user_count + 1)
      when 'destroy'
        reload
        update_attribute(:user_count, user_count - 1)
      else
        raise "unexpected action: #{event.action}"
    end
  end
end
