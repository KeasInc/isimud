require_relative "../../../../lib/isimud"

class User < ActiveRecord::Base
  belongs_to :company

  include Isimud::ModelWatcher

  watch_attributes :key, :login_count

  def key
    Base64.encode64("user-#{id}")
  end

end
