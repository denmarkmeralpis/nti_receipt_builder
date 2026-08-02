# frozen_string_literal: true

require 'action_view'

module NtiReceiptBuilder
  # Resolves every scalar variable to a formatted (not yet escaped) string. Missing keys
  # resolve to nil so presenters can apply their own fallback.
  #
  # A declared type wins; otherwise the value's class decides. Collection variables are
  # skipped — the collection presenter formats its own cells.
  class VariableResolver
    include ActionView::Helpers::NumberHelper

    def initialize(data, definitions:)
      @data = data || {}
      @definitions = definitions
    end

    def call
      definitions.each_with_object({}) do |(key, definition), resolved|
        next if definition.collection?

        resolved[key] = format_value(definition, data[key])
      end
    end

    private

    attr_reader :data, :definitions

    def format_value(definition, value)
      return nil if value.nil?

      case definition.type || TypeInference.call(value)
      when :currency then format_currency(value)
      when :datetime then format_datetime(value)
      else value.to_s
      end
    end

    def format_currency(value)
      number_to_currency(value, unit: NtiReceiptBuilder.config.currency_unit)
    rescue StandardError
      nil
    end

    def format_datetime(value)
      return value.to_s unless value.respond_to?(:strftime)

      value.strftime(NtiReceiptBuilder.config.datetime_format)
    rescue StandardError
      nil
    end
  end
end
