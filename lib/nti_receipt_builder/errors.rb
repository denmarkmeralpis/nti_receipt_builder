# frozen_string_literal: true

module NtiReceiptBuilder
  class Error < StandardError; end

  # Raised when the gem is used before required configuration has been supplied.
  class NotConfiguredError < Error; end

  # Raised when a Variables subclass is malformed — MAPPINGS missing or not a Hash, a mapped
  # method that does not exist, an override for a key absent from MAPPINGS, or more than one
  # key declaring `columns:`.
  class InvalidVariablesError < Error; end
end
