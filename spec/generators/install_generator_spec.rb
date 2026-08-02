# frozen_string_literal: true

require 'generators/nti_receipt_builder/install_generator'

RSpec.describe NtiReceiptBuilder::Generators::InstallGenerator do
  let(:templates_dir) { described_class.source_root }
  let(:migration_erb) { File.read(File.join(templates_dir, 'create_nti_receipt_templates.rb')) }
  let(:rendered_migration) { migration_erb.gsub('<%= migration_version %>', '[8.0]') }

  it 'ships all three templates' do
    expect(Dir.children(templates_dir))
      .to contain_exactly('initializer.rb', 'create_nti_receipt_templates.rb', 'turbo_stream_tags.rb')
  end

  it 'renders a migration that parses as Ruby' do
    expect { RubyVM::AbstractSyntaxTree.parse(rendered_migration) }.not_to raise_error
  end

  # Guards against the generator migration drifting away from what the model reads. A host
  # installing the gem fresh must get every column, not the subset that existed when the
  # dummy schema was last touched.
  it 'creates every column the model needs' do
    managed = NtiReceiptBuilder::Template.column_names - %w[id created_at updated_at]

    missing = managed.reject { |column| rendered_migration.include?(":#{column}") }

    expect(missing).to be_empty
  end

  it 'indexes the polymorphic owner' do
    expect(rendered_migration).to include('add_index :nti_receipt_templates, %i[owner_type owner_id]')
  end

  it 'defaults layout to an empty array' do
    expect(rendered_migration).to include('t.jsonb :layout, default: [], null: false')
  end

  it 'declares the initializer without enabling anything by default' do
    initializer = File.read(File.join(templates_dir, 'initializer.rb'))

    expect(initializer).to include('# config.variables_class')
  end

  describe 'the Turbo Stream helper template' do
    let(:helpers) { File.read(File.join(templates_dir, 'turbo_stream_tags.rb')) }

    it 'defines every helper the gem views call' do
      expect(helpers).to include('def open_modal', 'def close_modal', 'def toast', 'def reload_datatable')
    end
  end
end
