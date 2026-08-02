# frozen_string_literal: true

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'turbo-rails'

require 'nti_receipt_builder'

module Dummy
  # Minimal host application for the gem's specs: an owner model, a controller that
  # includes the gem's concern, and nothing else.
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.secret_key_base = 'nti_receipt_builder_dummy_secret'
    config.logger = Logger.new(IO::NULL)
    config.consider_all_requests_local = true
    config.action_dispatch.show_exceptions = :none
    config.hosts.clear
  end
end
