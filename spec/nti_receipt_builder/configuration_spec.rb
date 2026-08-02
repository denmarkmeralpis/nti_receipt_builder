# frozen_string_literal: true

class ConfigProbeVariables; end
class ConfigProbeTemplate; end

RSpec.describe NtiReceiptBuilder::Configuration do
  describe 'variables_class' do
    it 'accepts a class and resolves it back' do
      NtiReceiptBuilder.configure { |c| c.variables_class = ConfigProbeVariables }

      expect(NtiReceiptBuilder.variables_class).to eq(ConfigProbeVariables)
    end

    it 'accepts a string' do
      NtiReceiptBuilder.configure { |c| c.variables_class = 'ConfigProbeVariables' }

      expect(NtiReceiptBuilder.variables_class).to eq(ConfigProbeVariables)
    end

    # Retaining a reloadable application class would pin it and its constant tree past
    # every development reload, and would serve a stale class after the host reloads.
    it 'stores the name, never the class object' do
      NtiReceiptBuilder.configure { |c| c.variables_class = ConfigProbeVariables }

      config = NtiReceiptBuilder.config
      retained = config.instance_variables.map { |ivar| config.instance_variable_get(ivar) }

      expect(retained).not_to include(a_kind_of(Class))
      expect(config.variables_class_name).to eq('ConfigProbeVariables')
    end

    it 'raises when read before being configured' do
      expect { NtiReceiptBuilder.variables_class }
        .to raise_error(NtiReceiptBuilder::NotConfiguredError, /variables_class/)
    end

    it 'rejects an anonymous class' do
      expect { NtiReceiptBuilder.configure { |c| c.variables_class = Class.new } }
        .to raise_error(NtiReceiptBuilder::Error, /anonymous/)
    end
  end

  describe 'template_class' do
    it 'defaults to the gem template' do
      expect(NtiReceiptBuilder.config.template_class_name).to eq('NtiReceiptBuilder::Template')
    end

    it 'is overridable' do
      NtiReceiptBuilder.configure { |c| c.template_class = ConfigProbeTemplate }

      expect(NtiReceiptBuilder.template_class).to eq(ConfigProbeTemplate)
    end
  end

  describe 'formatting defaults' do
    it 'defaults the currency unit' do
      expect(NtiReceiptBuilder.config.currency_unit).to eq('₱')
    end

    it 'defaults the datetime format' do
      expect(NtiReceiptBuilder.config.datetime_format).to eq('%m/%d/%Y %I:%M %p')
    end

    # Defaults to the gem's own stylesheet so print output is correct with no host config.
    it 'defaults the print stylesheet to the gem bundle' do
      expect(NtiReceiptBuilder.config.print_stylesheet).to eq('nti_receipt_builder')
    end

    it 'allows the print stylesheet to be disabled' do
      NtiReceiptBuilder.configure { |c| c.print_stylesheet = nil }

      expect(NtiReceiptBuilder.config.print_stylesheet).to be_nil
    end
  end

  describe 'reset_config!' do
    it 'restores defaults' do
      NtiReceiptBuilder.configure { |c| c.currency_unit = '$' }
      NtiReceiptBuilder.reset_config!

      expect(NtiReceiptBuilder.config.currency_unit).to eq('₱')
    end
  end
end
