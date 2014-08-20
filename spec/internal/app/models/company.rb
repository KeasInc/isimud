require_relative "../../../../lib/isimud"

class Company < ActiveRecord::Base
  has_many :users

  include Isimud::ModelWatcher

  watch_attributes
end
