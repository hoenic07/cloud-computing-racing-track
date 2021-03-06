require './lib/swaggering'
require './api/postgres_connection'
require './api/redis_connection'
require 'newrelic_rpm'

# only need to extend if you want special configuration!
class MyApp < Swaggering
  self.configure do |config|
    config.api_version = '1.0.0' 
  end
end

# include the api files
Dir["./api/*.rb"].each { |file|
  require file
}
