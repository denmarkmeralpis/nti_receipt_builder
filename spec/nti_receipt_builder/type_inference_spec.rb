# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::TypeInference do
  it 'infers nil for nil so the element fallback applies' do
    expect(described_class.call(nil)).to be_nil
  end

  it 'infers collection for arrays' do
    expect(described_class.call([{ 'a' => 1 }])).to eq(:collection)
  end

  it 'infers currency for BigDecimal' do
    expect(described_class.call(BigDecimal('275.00'))).to eq(:currency)
  end

  it 'infers number for integers' do
    expect(described_class.call(2)).to eq(:number)
  end

  it 'infers number for floats' do
    expect(described_class.call(2.5)).to eq(:number)
  end

  it 'infers datetime for a Time' do
    expect(described_class.call(Time.now)).to eq(:datetime)
  end

  it 'infers datetime for a Date' do
    expect(described_class.call(Date.today)).to eq(:datetime)
  end

  it 'infers string for strings' do
    expect(described_class.call('ORD-1')).to eq(:string)
  end

  it 'infers string for anything else' do
    expect(described_class.call(:sym)).to eq(:string)
  end
end
