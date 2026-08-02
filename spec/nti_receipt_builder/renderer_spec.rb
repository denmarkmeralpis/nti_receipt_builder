# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::Renderer do
  let(:owner) { Owner.create!(name: 'Acme') }
  let(:height_mode) { 'content' }
  let(:template) do
    NtiReceiptBuilder::Template.create!(
      owner: owner, name: 'T', paper_size_key: 'roll_80mm', orientation: 'portrait',
      height_mode: height_mode, paper_width_mm: 80, paper_height_mm: 200,
      margin_top_mm: 2, margin_right_mm: 2, margin_bottom_mm: 2, margin_left_mm: 2,
      layout: layout
    )
  end
  let(:layout) do
    [
      { 'id' => 'txt', 'type' => 'text', 'text' => 'Hello', 'x_mm' => 1, 'y_mm' => 1,
        'width_mm' => 10, 'height_mm' => 5, 'z_index' => 2 },
      { 'id' => 'var', 'type' => 'variable', 'variable_key' => 'CUSTOMER_NAME', 'x_mm' => 1,
        'y_mm' => 10, 'width_mm' => 30, 'height_mm' => 5, 'z_index' => 1 }
    ]
  end

  before { NtiReceiptBuilder.configure { |c| c.variables_class = TestVariables } }

  describe 'without a receipt object' do
    subject(:result) { described_class.new(template: template).call }

    it 'renders from sample data' do
      expect(result.elements.find { |e| e.id == 'var' }.display_text).to eq('Juan Dela Cruz')
    end

    it 'sorts elements by z_index' do
      expect(result.elements.map(&:id)).to eq(%w[var txt])
    end

    it 'never calls a mapping method' do
      allow(TestVariables).to receive(:new).and_call_original
      result

      expect(TestVariables).not_to have_received(:new)
    end
  end

  describe 'with a receipt object' do
    subject(:result) { described_class.new(template: template, receipt_object: receipt).call }

    let(:receipt) do
      TestReceipt.new(customer_name: 'Maria Santos', store_name: 'Makati',
                      subtotal: BigDecimal('1'), created_at: Time.utc(2026, 1, 1), lines: [])
    end

    it 'renders from the receipt object' do
      expect(result.elements.find { |e| e.id == 'var' }.display_text).to eq('Maria Santos')
    end
  end

  describe 'presenter selection' do
    let(:layout) do
      [
        { 'id' => 'txt', 'type' => 'text', 'text' => 'x', 'x_mm' => 1, 'y_mm' => 1,
          'width_mm' => 5, 'height_mm' => 5 },
        { 'id' => 'var', 'type' => 'variable', 'variable_key' => 'CUSTOMER_NAME', 'x_mm' => 1,
          'y_mm' => 8, 'width_mm' => 5, 'height_mm' => 5 },
        { 'id' => 'lines', 'type' => 'order_lines', 'x_mm' => 1, 'y_mm' => 15,
          'width_mm' => 60, 'height_mm' => 20,
          'config' => { 'columns' => [{ 'key' => 'description', 'label' => 'Item',
                                        'width_mm' => 20, 'align' => 'left' }] } }
      ]
    end

    subject(:result) { described_class.new(template: template).call }

    it 'uses the element presenter for text' do
      expect(result.elements.find { |e| e.id == 'txt' }).to be_a(NtiReceiptBuilder::Presenters::Element)
    end

    it 'uses the element presenter for variables' do
      expect(result.elements.find { |e| e.id == 'var' }).to be_a(NtiReceiptBuilder::Presenters::Element)
    end

    it 'uses the collection presenter for order_lines' do
      expect(result.elements.find { |e| e.id == 'lines' })
        .to be_a(NtiReceiptBuilder::Presenters::Collection)
    end

    it 'feeds the collection its sample rows' do
      presenter = result.elements.find { |e| e.id == 'lines' }

      expect(presenter.rows.first['description']).to eq('Bottled Water 500ml')
    end
  end

  describe 'hidden elements' do
    let(:layout) do
      [{ 'id' => 'h', 'type' => 'text', 'text' => 'x', 'x_mm' => 1, 'y_mm' => 1,
         'width_mm' => 5, 'height_mm' => 5, 'visible' => false }]
    end

    it 'omits them' do
      expect(described_class.new(template: template).call.elements).to be_empty
    end
  end

  describe 'an empty layout' do
    let(:layout) { [] }

    it 'reports zero content height' do
      expect(described_class.new(template: template).call.content_height_mm).to eq(0.0)
    end
  end

  describe 'fallback' do
    let(:layout) do
      [{ 'id' => 'var', 'type' => 'variable', 'variable_key' => 'CUSTOMER_NAME', 'fallback' => 'N/A',
         'x_mm' => 1, 'y_mm' => 1, 'width_mm' => 10, 'height_mm' => 5 }]
    end

    it 'applies when the resolved value is blank' do
      receipt = TestReceipt.new(customer_name: '', store_name: '', subtotal: nil,
                                created_at: nil, lines: [])
      result = described_class.new(template: template, receipt_object: receipt).call

      expect(result.elements.first.display_text).to eq('N/A')
    end
  end

  describe 'content height' do
    let(:layout) do
      [{ 'id' => 'a', 'type' => 'text', 'text' => 'x', 'x_mm' => 1, 'y_mm' => 10,
         'width_mm' => 5, 'height_mm' => 15 }]
    end

    it 'is the lowest bottom edge' do
      expect(described_class.new(template: template).call.content_height_mm).to eq(25.0)
    end
  end

  describe 'overflow' do
    let(:layout) do
      [{ 'id' => 'tall', 'type' => 'text', 'text' => 'x', 'x_mm' => 1, 'y_mm' => 190,
         'width_mm' => 10, 'height_mm' => 20 }]
    end

    it 'never flags overflow in content height mode' do
      expect(described_class.new(template: template).call).not_to be_overflow
    end

    it 'flags content taller than the printable area in fixed mode' do
      # Built in content mode so the layout validator accepts the out-of-bounds element, then
      # switched without validation to exercise the fixed-mode overflow branch.
      template.update_column(:height_mode, 'fixed')

      expect(described_class.new(template: template.reload).call).to be_overflow
    end
  end
end
