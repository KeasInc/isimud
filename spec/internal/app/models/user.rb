require_relative "../../../../lib/isimud"

class User < ActiveRecord::Base
  belongs_to :company

  attr_accessor :events, :routing_keys
  include Isimud::EventObserver

  scope :active, -> {where('deactivated != ?', true)}

  def handle_event(event)
    self.events ||= Array.new
    self.events << event
  end

  def queue_prefix
    'test'
  end

  watch_attributes :key, :login_count

  def key
    Base64.encode64("user-#{id}")
  end

end
