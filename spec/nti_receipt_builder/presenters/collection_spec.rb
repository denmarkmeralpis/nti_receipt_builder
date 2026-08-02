# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::Presenters::Collection do
  subject(:presenter) { described_class.new(element, rows, definition: definition) }

  let(:definition) { TestVariables.collection_definition }
  let(:element) do
    { 'id' => 'lines', 'type' => 'order_lines', 'x_mm' => 0, 'y_mm' => 0, 'width_mm' => 60,
      'config' => { 'font_size_pt' => 8, 'row_spacing_mm' => 1.0,
                    'columns' => [
                      { 'key' => 'description', 'label' => 'Item', 'width_mm' => 24, 'align' => 'left' },
                      { 'key' => 'unit_price', 'label' => 'Price', 'width_mm' => 12, 'align' => 'right' }
                    ] } }
  end
  let(:rows) { [{ 'description' => 'Water', 'unit_price' => BigDecimal('25.00') }] }

  it 'reports its type' do
    expect(presenter.type).to eq('order_lines')
  end

  describe 'cell formatting' do
    it 'formats BigDecimal cells as currency' do
      expect(presenter.rows.first['unit_price']).to eq('₱25.00')
    end

    it 'passes string cells through' do
      expect(presenter.rows.first['description']).to eq('Water')
    end

    it 'renders integer cells plainly' do
      presenter = described_class.new(
        element.deep_merge('config' => { 'columns' => [{ 'key' => 'quantity', 'label' => 'Qty',
                                                         'width_mm' => 8, 'align' => 'center' }] }),
        [{ 'quantity' => 2 }],
        definition: definition
      )

      expect(presenter.rows.first['quantity']).to eq('2')
    end

    it 'renders a nil cell as an empty string' do
      presenter = described_class.new(element, [{ 'description' => 'X', 'unit_price' => nil }],
                                      definition: definition)

      expect(presenter.rows.first['unit_price']).to eq('')
    end

    context 'with a declared currency column type overriding inference' do
      let(:definition) do
        klass = Class.new(NtiReceiptBuilder::Variables) do
          def self.name = 'DeclaredColumnTypeProbe'
          const_set(:MAPPINGS, { 'ROWS' => 'rows' }.freeze)
          variable 'ROWS', columns: { 'unit_price' => { label: 'Price', type: :currency } }
          def rows = []
        end
        klass.collection_definition
      end
      let(:rows) { [{ 'description' => 'X', 'unit_price' => 25.0 }] }

      it 'formats a Float as currency because the column says so' do
        expect(presenter.rows.first['unit_price']).to eq('₱25.00')
      end
    end
  end

  describe 'column widths' do
    it 'normalises to percentages summing to 100' do
      total = presenter.columns.sum { |column| presenter.column_width_pct(column) }

      expect(total).to be_within(0.01).of(100.0)
    end

    it 'falls back to even columns when no widths are configured' do
      presenter = described_class.new(
        element.deep_merge('config' => { 'columns' => [
                             { 'key' => 'description', 'label' => 'A', 'width_mm' => 0, 'align' => 'left' },
                             { 'key' => 'unit_price', 'label' => 'B', 'width_mm' => 0, 'align' => 'left' }
                           ] }),
        rows, definition: definition
      )

      expect(presenter.column_width_pct(presenter.columns.first)).to eq(50.0)
    end
  end

  describe 'geometry' do
    it 'computes the text line height from the font size' do
      expect(presenter.text_line_height_mm).to be_within(0.0001).of((8 * 0.3528 * 1.25).round(4))
    end

    it 'adds row spacing to the line height for the row height' do
      expect(presenter.row_height_mm).to be_within(0.0001).of(presenter.text_line_height_mm + 1.0)
    end

    it 'computes content height from header plus rows' do
      expect(presenter.content_height_mm)
        .to be_within(0.001).of(presenter.header_height_mm + presenter.row_height_mm)
    end

    it 'drops the header height when the header is hidden' do
      presenter = described_class.new(element.deep_merge('config' => { 'show_header' => false }),
                                      rows, definition: definition)

      expect(presenter.header_height_mm).to eq(0.0)
    end
  end

  context 'with no rows' do
    let(:rows) { [] }

    it { is_expected.to be_empty }

    it 'still reserves the header height' do
      expect(presenter.content_height_mm).to eq(presenter.header_height_mm)
    end
  end

  # Spec section 5, item 5: cell rendering must stay O(rows x columns). Without memoisation,
  # column_width_pct recomputes the width sum once per cell.
  describe 'memoisation' do
    it 'builds columns once per instance' do
      expect(presenter.columns).to equal(presenter.columns)
    end

    it 'builds rows once per instance' do
      expect(presenter.rows).to equal(presenter.rows)
    end
  end
end
