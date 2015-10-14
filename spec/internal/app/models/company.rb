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
    user = User.find(event.parameters[:id])
    return unless user.company_id == id
    raise "unexpected action: #{event.action}" unless ['create','destroy' ].include?(event.action.to_s)
    self.user_count = User.where(company: self).count
    self.total_points = user_count * points_per_user
    save!
  end
end
