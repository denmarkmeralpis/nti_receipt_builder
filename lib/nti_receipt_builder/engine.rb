# frozen_string_literal: true

module NtiReceiptBuilder
  # Non-isolated on purpose: host controllers include NtiReceiptBuilder::TemplatesController
  # and must resolve this engine's views through the ordinary view-path chain. A non-isolated
  # engine contributes app/views, app/models, app/helpers and app/controllers/concerns to the
  # host automatically.
  class Engine < ::Rails::Engine
    # Propshaft picks up app/assets automatically; javascripts needs naming explicitly so the
    # Stimulus controllers are servable.
    initializer 'nti_receipt_builder.assets' do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.paths << root.join('app/assets/javascripts')
      app.config.assets.paths << root.join('app/assets/stylesheets')
    end

    initializer 'nti_receipt_builder.importmap', before: 'importmap' do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << root.join('config/importmap.rb')
    end

    # The render partials are rendered from whichever host controller prints a receipt, not
    # just the builder's own, so paper_style has to be available everywhere.
    initializer 'nti_receipt_builder.helpers' do
      ActiveSupport.on_load(:action_controller_base) do
        helper NtiReceiptBuilder::RenderHelper
      end
    end
  end
end
