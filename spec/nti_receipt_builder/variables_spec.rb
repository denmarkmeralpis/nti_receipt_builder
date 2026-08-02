# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::Variables do
  describe 'derivation' do
    it 'titleizes the key into a label by default' do
      expect(TestVariables.labels['STORE_NAME']).to eq('Store Name')
    end

    it 'titleizes multi-word keys correctly' do
      expect(TestVariables.labels['CUSTOMER_NAME']).to eq('Customer Name')
    end

    it 'honours a label override' do
      expect(TestVariables.labels['ORDER_DATETIME']).to eq('Order Date/Time')
    end

    it 'treats the key declaring columns as the collection' do
      expect(TestVariables.collection_key).to eq('ORDER_LINES')
    end

    it 'excludes the collection from scalar keys' do
      expect(TestVariables.scalar_keys).to contain_exactly(
        'CUSTOMER_NAME', 'STORE_NAME', 'ORDER_SUBTOTAL', 'ORDER_DATETIME'
      )
    end

    it 'exposes declared column keys in declaration order' do
      expect(TestVariables.collection_definition.column_keys)
        .to eq(%w[description quantity unit_price line_total])
    end

    it 'exposes declared column labels' do
      expect(TestVariables.collection_definition.column_label('unit_price')).to eq('Unit Price')
    end

    it 'titleizes an undeclared column label' do
      expect(TestVariables.collection_definition.column_label('sku')).to eq('Sku')
    end
  end

  # The builder JS reads this to build a fresh order_lines element. If it hardcoded column keys
  # instead, any host whose collection differs would get a layout its own validator rejects.
  describe 'default_columns_config' do
    subject(:config) { TestVariables.collection_definition.default_columns_config }

    it 'covers every declared column in order' do
      expect(config.map { |column| column['key'] })
        .to eq(%w[description quantity unit_price line_total])
    end

    it 'carries the declared labels' do
      expect(config.map { |column| column['label'] })
        .to eq(['Description', 'Qty', 'Unit Price', 'Total'])
    end

    it 'splits the default element width evenly when no widths are declared' do
      expect(config.map { |column| column['width_mm'] }).to all(eq(15.0))
    end

    it 'defaults alignment to left' do
      expect(config.map { |column| column['align'] }).to all(eq('left'))
    end

    it 'honours declared width and alignment' do
      klass = Class.new(described_class) do
        def self.name = 'ColumnGeometryProbe'
        const_set(:MAPPINGS, { 'ROWS' => 'rows' }.freeze)
        variable 'ROWS', columns: {
          'description' => { label: 'Item', width_mm: 24 },
          'total' => { label: 'Total', width_mm: 12, align: 'right' }
        }
        def rows = []
      end

      expect(klass.collection_definition.default_columns_config).to eq([
                                                                         { 'key' => 'description', 'label' => 'Item',
                                                                           'width_mm' => 24, 'align' => 'left' },
                                                                         { 'key' => 'total', 'label' => 'Total',
                                                                           'width_mm' => 12, 'align' => 'right' }
                                                                       ])
    end

    it 'is empty for a scalar variable' do
      expect(TestVariables.definitions['CUSTOMER_NAME'].default_columns_config).to eq([])
    end
  end

  describe 'sample_data' do
    it 'uses a declared string sample' do
      expect(TestVariables.sample_data['CUSTOMER_NAME']).to eq('Juan Dela Cruz')
    end

    it 'uses a declared decimal sample' do
      expect(TestVariables.sample_data['ORDER_SUBTOTAL']).to eq(BigDecimal('275.00'))
    end

    it 'resolves a lambda sample' do
      expect(TestVariables.sample_data['ORDER_DATETIME']).to eq(Time.utc(2026, 7, 31, 14, 32))
    end

    it 'falls back to the label when no sample is declared' do
      expect(TestVariables.sample_data['STORE_NAME']).to eq('Store Name')
    end

    it 'covers every declared key' do
      expect(TestVariables.sample_data.keys).to match_array(TestVariables.keys)
    end

    context 'for a collection with no declared sample' do
      let(:klass) do
        Class.new(described_class) do
          def self.name = 'CollectionSampleProbe'
          const_set(:MAPPINGS, { 'ROWS' => 'rows' }.freeze)
          variable 'ROWS', columns: { 'item' => { label: 'Item' } }
          def rows = []
        end
      end

      it 'derives filler rows from the column labels' do
        expect(klass.sample_data['ROWS']).to eq([
                                                  { 'item' => 'Item 1' },
                                                  { 'item' => 'Item 2' },
                                                  { 'item' => 'Item 3' }
                                                ])
      end
    end
  end

  describe 'resolve' do
    let(:receipt) do
      TestReceipt.new(
        customer_name: 'Maria Santos', store_name: 'Makati Branch',
        subtotal: BigDecimal('99.00'), created_at: Time.utc(2026, 1, 1),
        lines: [{ 'description' => 'Item' }]
      )
    end

    it 'sends each mapped method to build the data hash' do
      expect(TestVariables.new(receipt).resolve['CUSTOMER_NAME']).to eq('Maria Santos')
    end

    it 'returns raw unformatted values' do
      expect(TestVariables.new(receipt).resolve['ORDER_SUBTOTAL']).to eq(BigDecimal('99.00'))
    end

    it 'resolves the collection' do
      expect(TestVariables.new(receipt).resolve['ORDER_LINES']).to eq([{ 'description' => 'Item' }])
    end

    it 'covers every declared key' do
      expect(TestVariables.new(receipt).resolve.keys).to match_array(TestVariables.keys)
    end

    it 'exposes receipt_object to subclasses' do
      expect(TestVariables.new(receipt).receipt_object).to eq(receipt)
    end

    # Preserves the semantics of the OrderDataBuilder this replaces: a receipt printing
    # silently without its total is worse than a visible error.
    it 'propagates an error raised by a mapping method' do
      expect { TestVariables.new(nil).resolve }.to raise_error(NoMethodError)
    end
  end

  describe 'the schema' do
    it 'is frozen' do
      expect(TestVariables.definitions).to be_frozen
    end

    it 'is built once and reused' do
      expect(TestVariables.definitions).to equal(TestVariables.definitions)
    end

    it 'freezes each definition' do
      expect(TestVariables.definitions.values).to all(be_frozen)
    end
  end

  describe 'validation' do
    it 'rejects a missing MAPPINGS constant' do
      klass = Class.new(described_class) { def self.name = 'NoMappings' }

      expect { klass.definitions }
        .to raise_error(NtiReceiptBuilder::InvalidVariablesError, /MAPPINGS/)
    end

    it 'rejects MAPPINGS that is not a Hash' do
      klass = Class.new(described_class) do
        def self.name = 'BadMappings'
        const_set(:MAPPINGS, %w[A B].freeze)
      end

      expect { klass.definitions }
        .to raise_error(NtiReceiptBuilder::InvalidVariablesError, /must be a Hash/)
    end

    it 'rejects a mapped method that is not defined' do
      klass = Class.new(described_class) do
        def self.name = 'MissingMethod'
        const_set(:MAPPINGS, { 'A' => 'a' }.freeze)
      end

      expect { klass.definitions }
        .to raise_error(NtiReceiptBuilder::InvalidVariablesError, /undefined methods: a/)
    end

    it 'accepts a private mapped method' do
      klass = Class.new(described_class) do
        def self.name = 'PrivateMethod'
        const_set(:MAPPINGS, { 'A' => 'a' }.freeze)

        private

        def a = 'value'
      end

      expect(klass.new(nil).resolve).to eq('A' => 'value')
    end

    it 'rejects an override for a key absent from MAPPINGS' do
      klass = Class.new(described_class) do
        def self.name = 'UnknownKey'
        const_set(:MAPPINGS, { 'A' => 'a' }.freeze)
        def a = 1
        variable 'B', label: 'B'
      end

      expect { klass.definitions }
        .to raise_error(NtiReceiptBuilder::InvalidVariablesError, /not in MAPPINGS: B/)
    end

    it 'rejects more than one collection' do
      klass = Class.new(described_class) do
        def self.name = 'TwoCollections'
        const_set(:MAPPINGS, { 'A' => 'a', 'B' => 'b' }.freeze)
        def a = []
        def b = []
        variable 'A', columns: { 'x' => { label: 'X' } }
        variable 'B', columns: { 'y' => { label: 'Y' } }
      end

      expect { klass.definitions }
        .to raise_error(NtiReceiptBuilder::InvalidVariablesError, /only one variable/)
    end

    it 'allows no collection at all' do
      klass = Class.new(described_class) do
        def self.name = 'ScalarsOnly'
        const_set(:MAPPINGS, { 'A' => 'a' }.freeze)
        def a = 'x'
      end

      expect(klass.collection_key).to be_nil
      expect(klass.scalar_keys).to eq(['A'])
    end
  end
end
