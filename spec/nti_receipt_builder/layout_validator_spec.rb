# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::LayoutValidator do
  subject(:errors) { described_class.new(**args).call }

  let(:args) do
    { layout: layout, paper_width_mm: 80.0, paper_height_mm: 200.0,
      margin_top_mm: 2.0, margin_right_mm: 2.0, margin_bottom_mm: 2.0, margin_left_mm: 2.0,
      height_mode: 'fixed', variables_class: TestVariables }
  end

  def element(overrides = {})
    { 'id' => 'a', 'type' => 'text', 'text' => 'Hi', 'x_mm' => 1, 'y_mm' => 1,
      'width_mm' => 10, 'height_mm' => 5 }.merge(overrides)
  end

  context 'with a valid layout' do
    let(:layout) { [element] }

    it { is_expected.to be_empty }
  end

  context 'when layout is not an array' do
    let(:layout) { { 'id' => 'a' } }

    it { is_expected.to include('must be an array of elements') }
  end

  describe 'variable keys' do
    context 'with a key the variables class does not declare' do
      let(:layout) { [element('type' => 'variable', 'variable_key' => 'NOT_A_KEY')] }

      it { is_expected.to include(a_string_matching(/unknown variable_key/)) }
    end

    context 'with a key the variables class declares' do
      let(:layout) { [element('type' => 'variable', 'variable_key' => 'CUSTOMER_NAME')] }

      it { is_expected.to be_empty }
    end

    context 'when the collection key is used as a scalar variable' do
      let(:layout) { [element('type' => 'variable', 'variable_key' => 'ORDER_LINES')] }

      it { is_expected.to include(a_string_matching(/unknown variable_key/)) }
    end
  end

  describe 'order_lines columns' do
    def order_lines(columns)
      [element('type' => 'order_lines', 'config' => { 'columns' => columns })]
    end

    context 'with a column key the variables class does not declare' do
      let(:layout) do
        order_lines([{ 'key' => 'sku', 'label' => 'SKU', 'width_mm' => 10, 'align' => 'left' }])
      end

      it { is_expected.to include(a_string_matching(/unknown key/)) }
    end

    context 'with a declared column key' do
      let(:layout) do
        order_lines([{ 'key' => 'description', 'label' => 'Item', 'width_mm' => 10, 'align' => 'left' }])
      end

      it { is_expected.to be_empty }
    end

    context 'with a duplicated column key' do
      let(:layout) do
        order_lines([
                      { 'key' => 'description', 'label' => 'Item', 'width_mm' => 10, 'align' => 'left' },
                      { 'key' => 'description', 'label' => 'Again', 'width_mm' => 10, 'align' => 'left' }
                    ])
      end

      it { is_expected.to include(a_string_matching(/duplicates column key/)) }
    end

    context 'with no columns at all' do
      let(:layout) { order_lines([]) }

      it { is_expected.to include(a_string_matching(/at least 1 order_lines column/)) }
    end

    # The gem carries no column vocabulary, so it must not cap the count either: the host's
    # declared columns, with duplicates rejected, are already the ceiling.
    context 'with every column a wider host declares' do
      let(:args) { super().merge(variables_class: WideVariables) }
      let(:layout) do
        order_lines(WideVariables.collection_definition.default_columns_config)
      end

      it 'accepts more columns than the gem would have guessed at' do
        expect(layout.first['config']['columns'].size).to be > 6
        expect(errors).to be_empty
      end
    end
  end

  describe 'structural limits' do
    context 'with too many elements' do
      let(:layout) { Array.new(61) { |i| element('id' => "e#{i}") } }

      it { is_expected.to include(a_string_matching(/at most 60 elements/)) }
    end

    context 'with duplicate ids' do
      let(:layout) { [element, element] }

      it { is_expected.to include(a_string_matching(/duplicate id/)) }
    end

    context 'with a missing id' do
      let(:layout) { [element('id' => '')] }

      it { is_expected.to include(a_string_matching(/missing a valid id/)) }
    end

    context 'with an unknown type' do
      let(:layout) { [element('type' => 'barcode')] }

      it { is_expected.to include(a_string_matching(/unknown type/)) }
    end

    context 'with an element below the minimum size' do
      let(:layout) { [element('width_mm' => 0.5)] }

      it { is_expected.to include(a_string_matching(/minimum size/)) }
    end

    context 'with a negative position' do
      let(:layout) { [element('x_mm' => -1)] }

      it { is_expected.to include(a_string_matching(/negative position/)) }
    end
  end

  describe 'styles' do
    context 'with a disallowed property' do
      let(:layout) { [element('styles' => { 'color' => 'red' })] }

      it { is_expected.to include(a_string_matching(/disallowed style property/)) }
    end

    context 'with an out-of-range numeric' do
      let(:layout) { [element('styles' => { 'font_size_pt' => 200 })] }

      it { is_expected.to include(a_string_matching(/out-of-range font_size_pt/)) }
    end

    context 'with an invalid enum' do
      let(:layout) { [element('styles' => { 'text_align' => 'justify' })] }

      it { is_expected.to include(a_string_matching(/invalid text_align/)) }
    end
  end

  describe 'paper bounds' do
    context 'when an element extends beyond the paper width' do
      let(:layout) { [element('x_mm' => 75, 'width_mm' => 20)] }

      it { is_expected.to include(a_string_matching(/beyond the paper width/)) }
    end

    context 'when an element extends beyond the paper height' do
      let(:layout) { [element('y_mm' => 195, 'height_mm' => 20)] }

      it { is_expected.to include(a_string_matching(/beyond the paper height/)) }
    end

    context 'when height_mode is content' do
      let(:args) { super().merge(height_mode: 'content') }
      let(:layout) { [element('y_mm' => 500, 'height_mm' => 20)] }

      it 'does not enforce paper height' do
        expect(errors).to be_empty
      end
    end
  end

  describe 'text elements' do
    context 'with blank text' do
      let(:layout) { [element('text' => '')] }

      it { is_expected.to include(a_string_matching(/missing or too-long text/)) }
    end

    context 'with over-long text' do
      let(:layout) { [element('text' => 'x' * 501)] }

      it { is_expected.to include(a_string_matching(/missing or too-long text/)) }
    end
  end

  describe 'defaulting to the configured variables class' do
    let(:args) do
      { layout: [element('type' => 'variable', 'variable_key' => 'CUSTOMER_NAME')],
        paper_width_mm: 80.0, paper_height_mm: 200.0, margin_top_mm: 2.0, margin_right_mm: 2.0,
        margin_bottom_mm: 2.0, margin_left_mm: 2.0, height_mode: 'fixed' }
    end

    before { NtiReceiptBuilder.configure { |c| c.variables_class = TestVariables } }

    it 'reads scalar keys from configuration when none is passed' do
      expect(errors).to be_empty
    end
  end
end
