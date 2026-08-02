# frozen_string_literal: true

require 'bigdecimal'

module NtiReceiptBuilder
  # Maps a resolved value to the formatting type used by VariableResolver and the collection
  # presenter. Inference is the default so a host declares nothing for the common cases; a
  # Variables subclass overrides it per key with `variable KEY, type: :currency`.
  #
  # Deciding at format time rather than declaration time means real data and preview samples
  # travel the same path.
  module TypeInference
    module_function

    def call(value)
      case value
      when nil then nil
      when Array then :collection
      when BigDecimal then :currency
      when Numeric then :number
      else
        value.respond_to?(:strftime) ? :datetime : :string
      end
    end
  end
end
