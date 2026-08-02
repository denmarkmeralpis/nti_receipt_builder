# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

# The dummy app loads the railties first, then the gem — so Rails::Engine is defined by the
# time lib/nti_receipt_builder.rb decides whether to load our Engine. Requiring the gem
# directly here would skip the engine entirely.
require_relative 'dummy/config/application'

Rails.application.initialize!

require 'rspec/rails'

ActiveRecord::Schema.verbose = false
load Rails.root.join('db/schema.rb')

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configuration is global state; every example starts from defaults.
  config.before do
    NtiReceiptBuilder.reset_config!
  end
end
