# frozen_string_literal: true

module NtiReceiptBuilder
  # Runtime configuration.
  #
  # Class references are held by NAME, never as Class objects. Retaining a reloadable
  # application class here would pin that class and its whole constant tree past every
  # development reload, and would serve a stale class after the host reloads its code.
  class Configuration
    DEFAULT_CURRENCY_UNIT = '₱'
    DEFAULT_DATETIME_FORMAT = '%m/%d/%Y %I:%M %p'
    DEFAULT_TEMPLATE_CLASS = 'NtiReceiptBuilder::Template'
    DEFAULT_PRINT_STYLESHEET = 'nti_receipt_builder'

    attr_accessor :currency_unit, :datetime_format
    # Stylesheet(s) the standalone print document loads — a name or an array of names. Defaults
    # to the gem's own so print output is correct without host configuration. A host whose
    # bundle does not include this gem's CSS should list both, e.g. ['app', 'nti_receipt_builder'].
    attr_accessor :print_stylesheet
    attr_reader :variables_class_name, :template_class_name

    def initialize
      @currency_unit = DEFAULT_CURRENCY_UNIT
      @datetime_format = DEFAULT_DATETIME_FORMAT
      @print_stylesheet = DEFAULT_PRINT_STYLESHEET
      @variables_class_name = nil
      @template_class_name = DEFAULT_TEMPLATE_CLASS
    end

    def variables_class=(value)
      @variables_class_name = class_name_for(value)
    end

    def variables_class
      if @variables_class_name.nil?
        raise NotConfiguredError,
              'NtiReceiptBuilder.config.variables_class must be set to a NtiReceiptBuilder::Variables subclass'
      end

      @variables_class_name.constantize
    end

    def template_class=(value)
      @template_class_name = class_name_for(value)
    end

    def template_class
      @template_class_name.constantize
    end

    private

    def class_name_for(value)
      return value.to_s unless value.is_a?(Class)

      value.name || raise(Error, 'cannot configure an anonymous class — give it a name or pass a String')
    end
  end
end
