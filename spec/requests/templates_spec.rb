# frozen_string_literal: true

RSpec.describe 'Receipt templates', type: :request do
  let!(:owner) { Owner.create!(name: 'Acme') }
  let(:other_owner) { Owner.create!(name: 'Other') }

  before { NtiReceiptBuilder.configure { |c| c.variables_class = TestVariables } }

  def create_template(for_owner, name: 'Mine', **overrides)
    NtiReceiptBuilder::Template.create!(
      { owner: for_owner, name: name, paper_size_key: 'roll_80mm', orientation: 'portrait',
        height_mode: 'content', paper_width_mm: 80, paper_height_mm: 200,
        margin_top_mm: 2, margin_right_mm: 2, margin_bottom_mm: 2, margin_left_mm: 2,
        layout: [] }.merge(overrides)
    )
  end

  def valid_params(**overrides)
    { receipt_template: {
      name: 'New', paper_size_key: 'roll_80mm', orientation: 'portrait', height_mode: 'content',
      paper_width_mm: 80, paper_height_mm: 200, margin_top_mm: 2, margin_right_mm: 2,
      margin_bottom_mm: 2, margin_left_mm: 2, layout: '[]'
    }.merge(overrides) }
  end

  describe 'tenant scoping' do
    it 'lists only the owner\'s templates' do
      create_template(owner, name: 'Mine')
      create_template(other_owner, name: 'Theirs')

      get '/receipt_templates'

      expect(response.body).to eq('Mine')
    end

    it 'refuses to load another owner\'s template' do
      foreign = create_template(other_owner, name: 'Theirs')

      get "/receipt_templates/#{foreign.id}/edit"

      expect(response).to redirect_to('/receipt_templates')
    end

    it 'refuses to set another owner\'s template as default' do
      foreign = create_template(other_owner, name: 'Theirs')

      patch "/receipt_templates/#{foreign.id}/set_default"

      expect(foreign.reload).not_to be_is_default
    end

    it 'refuses to destroy another owner\'s template' do
      foreign = create_template(other_owner, name: 'Theirs')

      delete "/receipt_templates/#{foreign.id}"

      expect(NtiReceiptBuilder::Template.where(id: foreign.id)).to exist
    end

    it 'assigns the owner on create' do
      post '/receipt_templates', params: valid_params

      expect(NtiReceiptBuilder::Template.find_by(name: 'New').owner).to eq(owner)
    end
  end

  describe 'create' do
    it 'persists a valid template' do
      expect { post '/receipt_templates', params: valid_params }
        .to change(NtiReceiptBuilder::Template, :count).by(1)
    end

    it 'redirects to the builder' do
      post '/receipt_templates', params: valid_params
      created = NtiReceiptBuilder::Template.find_by(name: 'New')

      expect(response).to redirect_to("/receipt_templates/#{created.id}/edit")
    end
  end

  describe 'destroy' do
    it 'removes the template' do
      template = create_template(owner)

      expect { delete "/receipt_templates/#{template.id}" }
        .to change(NtiReceiptBuilder::Template, :count).by(-1)
    end
  end

  describe 'set_default' do
    it 'makes the template default and clears the previous one' do
      first = create_template(owner, name: 'A', is_default: true)
      second = create_template(owner, name: 'B')

      patch "/receipt_templates/#{second.id}/set_default"

      expect(second.reload).to be_is_default
      expect(first.reload).not_to be_is_default
    end
  end

  describe 'rendering the gem views' do
    it 'renders the new form' do
      get '/receipt_templates/new'

      expect(response).to have_http_status(:ok)
    end

    it 'lists the variables class keys in the elements panel' do
      template = create_template(owner)

      get "/receipt_templates/#{template.id}/edit"

      expect(response.body).to include('Customer Name', 'Order Date/Time', 'Order Lines')
    end

    it 'renders the preview page with sample data' do
      template = create_template(owner, layout: [
                                   { 'id' => 'var', 'type' => 'variable',
                                     'variable_key' => 'CUSTOMER_NAME', 'x_mm' => 1, 'y_mm' => 1,
                                     'width_mm' => 30, 'height_mm' => 5 }
                                 ])

      get "/receipt_templates/#{template.id}/preview"

      expect(response.body).to include('Juan Dela Cruz')
    end

    it 'renders the print page without a layout' do
      template = create_template(owner)

      get "/receipt_templates/#{template.id}/print"

      expect(response).to have_http_status(:ok)
    end

    it 're-renders new with errors when the form is invalid' do
      post '/receipt_templates', params: valid_params(name: '')

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'escapes text element content rather than trusting it' do
      template = create_template(owner, layout: [
                                   { 'id' => 'txt', 'type' => 'text', 'text' => '<script>x</script>',
                                     'x_mm' => 1, 'y_mm' => 1, 'width_mm' => 30, 'height_mm' => 5 }
                                 ])

      get "/receipt_templates/#{template.id}/preview"

      expect(response.body).to include('&lt;script&gt;')
      expect(response.body).not_to include('<script>x</script>')
    end
  end

  describe 'a missing template' do
    it 'redirects rather than raising' do
      get '/receipt_templates/999999/edit'

      expect(response).to redirect_to('/receipt_templates')
    end
  end

  describe 'the receipt_owner contract' do
    it 'raises NotImplementedError when a host does not define it' do
      controller = Class.new(ActionController::Base) do
        include NtiReceiptBuilder::TemplatesController

        def self.name = 'HostWithoutOwner'
      end

      expect { controller.new.send(:receipt_owner) }
        .to raise_error(NotImplementedError, /must define #receipt_owner/)
    end
  end
end
