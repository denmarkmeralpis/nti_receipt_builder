# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::VariableResolver do
  subject(:resolved) { described_class.new(data, definitions: TestVariables.definitions).call }

  let(:data) { TestVariables.sample_data }

  it 'covers every scalar key' do
    expect(resolved.keys).to match_array(TestVariables.scalar_keys)
  end

  it 'omits the collection key' do
    expect(resolved).not_to have_key('ORDER_LINES')
  end

  it 'formats BigDecimal as currency using the configured unit' do
    expect(resolved['ORDER_SUBTOTAL']).to eq('₱275.00')
  end

  it 'honours a configured currency unit' do
    NtiReceiptBuilder.config.currency_unit = '$'

    expect(resolved['ORDER_SUBTOTAL']).to eq('$275.00')
  end

  it 'formats times using the configured format' do
    expect(resolved['ORDER_DATETIME']).to eq('07/31/2026 02:32 PM')
  end

  it 'honours a configured datetime format' do
    NtiReceiptBuilder.config.datetime_format = '%Y-%m-%d'

    expect(resolved['ORDER_DATETIME']).to eq('2026-07-31')
  end

  it 'passes strings through' do
    expect(resolved['CUSTOMER_NAME']).to eq('Juan Dela Cruz')
  end

  context 'when a key is missing from the data' do
    let(:data) { TestVariables.sample_data.except('CUSTOMER_NAME') }

    it 'resolves it to nil so the element fallback applies' do
      expect(resolved['CUSTOMER_NAME']).to be_nil
    end
  end

  context 'when a key is explicitly nil' do
    let(:data) { TestVariables.sample_data.merge('CUSTOMER_NAME' => nil) }

    it 'resolves to nil' do
      expect(resolved['CUSTOMER_NAME']).to be_nil
    end
  end

  context 'when data is nil entirely' do
    let(:data) { nil }

    it 'resolves every scalar to nil rather than raising' do
      expect(resolved.values).to all(be_nil)
    end
  end

  context 'when a datetime-typed value is already a string' do
    let(:data) { TestVariables.sample_data.merge('ORDER_DATETIME' => 'already-a-string') }

    it 'falls back to the string form' do
      expect(resolved['ORDER_DATETIME']).to eq('already-a-string')
    end
  end

  context 'with an explicit type override that contradicts the value class' do
    let(:klass) do
      Class.new(NtiReceiptBuilder::Variables) do
        def self.name = 'TypeOverrideProbe'
        const_set(:MAPPINGS, { 'TOTAL' => 'total' }.freeze)
        variable 'TOTAL', type: :currency, sample: 12.5
        def total = 12.5
      end
    end

    it 'honours the declared type over inference' do
      resolved = described_class.new(klass.sample_data, definitions: klass.definitions).call

      expect(resolved['TOTAL']).to eq('₱12.50')
    end
  end
end
