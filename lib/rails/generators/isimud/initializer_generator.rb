module Isimud
  module Generators
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

      desc 'Creates an Isimud gem initializer file at config/isimud.yml'
      def create_initializer_file
        template 'initializer.rb', File.join(Rails.root, 'config', 'initializers', 'isimud.rb')
      end
    end
  end
end