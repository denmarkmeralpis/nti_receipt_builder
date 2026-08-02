# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/enumerable'

require_relative 'nti_receipt_builder/version'
require_relative 'nti_receipt_builder/errors'
require_relative 'nti_receipt_builder/configuration'
require_relative 'nti_receipt_builder/type_inference'
require_relative 'nti_receipt_builder/variable_definition'
require_relative 'nti_receipt_builder/variables'
require_relative 'nti_receipt_builder/elements'
require_relative 'nti_receipt_builder/layout_validator'
require_relative 'nti_receipt_builder/variable_resolver'
require_relative 'nti_receipt_builder/presenters/element'
require_relative 'nti_receipt_builder/presenters/collection'
require_relative 'nti_receipt_builder/render_result'
require_relative 'nti_receipt_builder/renderer'
require_relative 'nti_receipt_builder/set_default'
require_relative 'nti_receipt_builder/template_form'
require_relative 'nti_receipt_builder/engine' if defined?(Rails::Engine)

# A receipt template builder and renderer.
#
#   NtiReceiptBuilder.configure { |config| config.variables_class = OrderReceiptVariables }
#
# The configured Variables subclass supplies the placeholder vocabulary, so the gem itself
# carries no domain terms. See NtiReceiptBuilder::Variables.
module NtiReceiptBuilder
  class << self
    def configure
      yield(config) if block_given?
      config
    end

    def config
      @config ||= Configuration.new
    end

    # Resets configuration to defaults. Intended for test suites.
    def reset_config!
      @config = Configuration.new
    end

    def variables_class = config.variables_class
    def template_class = config.template_class
  end
end
