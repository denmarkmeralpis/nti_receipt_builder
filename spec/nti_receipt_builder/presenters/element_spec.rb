# frozen_string_literal: true

RSpec.describe NtiReceiptBuilder::Presenters::Element do
  subject(:presenter) { described_class.new(element, resolved) }

  let(:resolved) { { 'CUSTOMER_NAME' => 'Juan Dela Cruz' } }
  let(:element) do
    { 'id' => 'var', 'type' => 'variable', 'variable_key' => 'CUSTOMER_NAME',
      'x_mm' => 1.5, 'y_mm' => 2.5, 'width_mm' => 30, 'height_mm' => 5, 'z_index' => 3 }
  end

  describe 'geometry' do
    it 'exposes millimetre coordinates as floats' do
      expect([presenter.x_mm, presenter.y_mm, presenter.width_mm, presenter.height_mm])
        .to eq([1.5, 2.5, 30.0, 5.0])
    end

    it 'defaults z_index to zero' do
      expect(described_class.new(element.except('z_index'), resolved).z_index).to eq(0)
    end
  end

  describe 'css_style' do
    it 'positions absolutely in millimetres' do
      expect(presenter.css_style)
        .to eq('position: absolute; left: 1.5mm; top: 2.5mm; width: 30.0mm; height: 5.0mm; z-index: 3')
    end

    it 'appends whitelisted style declarations' do
      styled = described_class.new(
        element.merge('styles' => { 'font_size_pt' => 10, 'font_weight' => 'bold',
                                    'text_align' => 'center', 'line_height' => 1.2 }),
        resolved
      )

      expect(styled.css_style)
        .to end_with('font-size: 10pt; font-weight: bold; text-align: center; line-height: 1.2')
    end

    it 'ignores unknown style keys' do
      styled = described_class.new(element.merge('styles' => { 'color' => 'red' }), resolved)

      expect(styled.css_style).not_to include('color')
    end

    it 'tolerates a non-hash styles value' do
      styled = described_class.new(element.merge('styles' => 'nope'), resolved)

      expect(styled.css_style).to end_with('z-index: 3')
    end
  end

  describe 'display_text' do
    it 'renders the resolved variable' do
      expect(presenter.display_text).to eq('Juan Dela Cruz')
    end

    it 'wraps the value in prefix and suffix' do
      wrapped = described_class.new(element.merge('prefix' => 'Mr. ', 'suffix' => ' (VIP)'), resolved)

      expect(wrapped.display_text).to eq('Mr. Juan Dela Cruz (VIP)')
    end

    it 'applies the fallback when the value is nil' do
      fallen = described_class.new(element.merge('fallback' => 'N/A'), {})

      expect(fallen.display_text).to eq('N/A')
    end

    it 'applies the fallback when the value is blank' do
      fallen = described_class.new(element.merge('fallback' => 'N/A'), { 'CUSTOMER_NAME' => '' })

      expect(fallen.display_text).to eq('N/A')
    end

    it 'renders a text element from its own text' do
      text = described_class.new({ 'id' => 't', 'type' => 'text', 'text' => 'Thank you!' }, resolved)

      expect(text.display_text).to eq('Thank you!')
    end

    it 'never marks output html_safe — the partials escape' do
      text = described_class.new({ 'id' => 't', 'type' => 'text', 'text' => '<b>x</b>' }, resolved)

      expect(text.display_text).not_to be_html_safe
    end
  end
end
