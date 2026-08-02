# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module NtiReceiptBuilder
  module Generators
    # rails generate nti_receipt_builder:install
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Creates the nti_receipt_builder initializer, migration, and (if absent) the ' \
           'Turbo Stream helpers the gem views depend on.'

      def create_initializer
        template 'initializer.rb', 'config/initializers/nti_receipt_builder.rb'
      end

      def create_migration_file
        migration_template 'create_nti_receipt_templates.rb',
                           'db/migrate/create_nti_receipt_templates.rb'
      end

      # Only for hosts that do not already extend Turbo::Streams::TagBuilder. A host that
      # already defines open_modal has its own conventions; overwriting them would be wrong.
      def create_turbo_stream_helpers
        if turbo_stream_helpers_present?
          say_status :skip, 'config/initializers/turbo_stream_tags.rb (host already defines open_modal)', :yellow
          return
        end

        template 'turbo_stream_tags.rb', 'config/initializers/turbo_stream_tags.rb'
      end

      private

      def turbo_stream_helpers_present?
        defined?(Turbo::Streams::TagBuilder) &&
          Turbo::Streams::TagBuilder.method_defined?(:open_modal)
      end

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
