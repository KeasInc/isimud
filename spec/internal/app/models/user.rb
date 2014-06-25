require_relative "../../../../lib/isimud/model_watcher"

class User < ActiveRecord::Base

  include ModelWatcher

  watch_attributes

end
