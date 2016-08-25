require "bundler/gem_tasks"

namespace 'isimud' do
  task :makedoc do
    system("yardoc --no-private 'lib/isimud.rb lib/isimud/*.rb' - README.md LICENSE.txt")
  end
end