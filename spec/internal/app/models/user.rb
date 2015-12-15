require_relative "../../../../lib/isimud"

class User < ActiveRecord::Base
  include Isimud::EventObserver

  belongs_to :company

  attr_accessor :events

  serialize :keys, Array

  scope :active, -> {where('deactivated != ?', true)}

  def handle_event(event)
    self.events ||= Array.new
    self.events << event
  end

  def queue_prefix
    'test'
  end

  def routing_keys
    keys
  end

  def enable_listener?
    !deactivated
  end

  watch_attributes :key, :login_count

  def key
    Base64.encode64("user-#{id}")
  end

end
