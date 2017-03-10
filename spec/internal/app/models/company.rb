require_relative "../../../../lib/isimud"

class Company < ActiveRecord::Base
  include Isimud::EventObserver

  has_many :users

  def self.find_active_observers
    where(active: true).all
  end

  def enable_listener?
    active
  end

  def observed_exchange
    'isimud.test.events'
  end

  def routing_keys
    ["*.User.create", "*.User.destroy"]
  end

  def handle_event(event)
    Rails.logger.info "Company#handle_event: id=#{id} event=#{event.inspect}"
    user = User.find(event.parameters[:id])
    return unless user.company_id == id
    case event.action
      when :create
        Rails.logger.info "recording new user for company #{id}"
        self.user_count += 1
        self.total_points += points_per_user
      when :destroy
        self.user_count -= 1
        self.total_points -= points_per_user
    end
    save!
  end
end
