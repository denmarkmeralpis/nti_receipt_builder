# frozen_string_literal: true

module NtiReceiptBuilder
  # Base class for a host application's receipt variable vocabulary.
  #
  #   class OrderReceiptVariables < NtiReceiptBuilder::Variables
  #     MAPPINGS = {
  #       'ORDER_REFERENCE' => 'order_reference',
  #       'STORE_NAME'      => 'store_name'
  #     }.freeze
  #
  #     def order_reference = receipt_object.reference
  #     def store_name      = receipt_object.address.name
  #   end
  #
  # MAPPINGS supplies the placeholder keys and the method producing each value. Everything
  # else — label, formatting type, preview sample — is derived, and overridden per key with
  # `variable`. The key that declares `columns:` is the collection.
  #
  # The schema is built once on first read and frozen, so render-path reads take no lock.
  # It is memoised on the subclass itself, so a host code reload discards it along with the
  # class it describes — there is no separate cache to invalidate and nothing that outlives
  # what it points at.
  class Variables
    Schema = Struct.new(:definitions, :labels, :scalar_keys, :collection_key, keyword_init: true)
    private_constant :Schema

    class << self
      # Override any derived aspect of a key already present in MAPPINGS.
      #
      #   variable 'ORDER_DATETIME', label: 'Order Date/Time', sample: -> { Time.current }
      #   variable 'ORDER_LINES',    columns: { 'description' => { label: 'Item' } }
      #
      # Column options: label:, type:, width_mm:, align: — all optional.
      def variable(key, label: nil, type: nil, sample: nil, columns: nil)
        overrides[key.to_s] = { label: label, type: type, sample: sample, columns: columns }
        @schema = nil
        self
      end

      def definitions = schema.definitions
      def labels = schema.labels
      def scalar_keys = schema.scalar_keys
      def collection_key = schema.collection_key
      def keys = definitions.keys
      def collection_definition = collection_key && definitions[collection_key]

      def sample_data
        definitions.transform_values(&:sample)
      end

      def overrides
        @overrides ||= {}
      end

      private

      def schema
        @schema ||= build_schema
      end

      def mappings
        unless const_defined?(:MAPPINGS, false)
          raise InvalidVariablesError, "#{inspect} must define a MAPPINGS constant"
        end

        const_get(:MAPPINGS, false)
      end

      def build_schema
        raw = mappings
        raise InvalidVariablesError, "#{inspect}: MAPPINGS must be a Hash" unless raw.is_a?(Hash)

        validate_override_keys!(raw)
        validate_mapped_methods!(raw)

        definitions = build_definitions(raw)
        validate_single_collection!(definitions)

        Schema.new(
          definitions: definitions,
          labels: definitions.transform_values(&:label).freeze,
          scalar_keys: definitions.reject { |_, definition| definition.collection? }.keys.freeze,
          collection_key: definitions.each_value.find(&:collection?)&.key
        ).freeze
      end

      def build_definitions(raw)
        raw.each_with_object({}) do |(key, method_name), acc|
          string_key = key.to_s
          override = overrides.fetch(string_key, {})

          acc[string_key] = VariableDefinition.new(
            key: string_key,
            method_name: method_name,
            label: override[:label] || string_key.titleize,
            type: override[:type],
            sample: override[:sample],
            columns: normalize_columns(override[:columns])
          )
        end.freeze
      end

      def normalize_columns(columns)
        return nil if columns.nil?

        columns.each_with_object({}) do |(column_key, options), acc|
          acc[column_key.to_s] = {
            label: options[:label],
            type: options[:type],
            width_mm: options[:width_mm],
            align: options[:align]
          }.compact.freeze
        end.freeze
      end

      def validate_override_keys!(raw)
        unknown = overrides.keys - raw.keys.map(&:to_s)
        return if unknown.empty?

        raise InvalidVariablesError,
              "#{inspect}: `variable` called for keys not in MAPPINGS: #{unknown.join(', ')}"
      end

      def validate_mapped_methods!(raw)
        missing = raw.values.map(&:to_s).reject do |method_name|
          method_defined?(method_name) || private_method_defined?(method_name)
        end
        return if missing.empty?

        raise InvalidVariablesError,
              "#{inspect}: MAPPINGS references undefined methods: #{missing.join(', ')}"
      end

      def validate_single_collection!(definitions)
        collections = definitions.each_value.select(&:collection?).map(&:key)
        return if collections.size <= 1

        raise InvalidVariablesError,
              "#{inspect}: only one variable may declare `columns:` (got #{collections.join(', ')})"
      end
    end

    attr_reader :receipt_object

    def initialize(receipt_object)
      @receipt_object = receipt_object
    end

    # Raw values, unformatted — VariableResolver applies formatting. An error raised by a
    # mapping method propagates deliberately: a receipt printing silently without its total
    # is worse than a visible failure.
    def resolve
      self.class.definitions.each_with_object({}) do |(key, definition), acc|
        acc[key] = send(definition.method_name)
      end
    end
  end
end
