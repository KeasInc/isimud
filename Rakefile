require "bundler/gem_tasks"

namespace 'isimud' do
  task :makedoc do
    system("yardoc --no-private 'lib/**/*.rb' - README.md LICENSE.txt")
  end
end