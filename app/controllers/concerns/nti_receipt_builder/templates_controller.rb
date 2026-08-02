# frozen_string_literal: true

module NtiReceiptBuilder
  # The builder's actions, for inclusion in a host controller that owns routing,
  # authorization and tenancy.
  #
  #   class Partner::ReceiptTemplatesController < PartnerController
  #     include NtiReceiptBuilder::TemplatesController
  #
  #     private
  #
  #     def receipt_owner = current_account
  #   end
  #
  # Every query runs through `receipt_owner`, so the tenant boundary stays visible in host
  # code rather than in a configured lambda. Hosts may override any action or navigation
  # hook — a method defined in the including class wins over the one mixed in here.
  module TemplatesController
    extend ActiveSupport::Concern

    VIEW_PREFIX = 'nti_receipt_builder/templates'

    included do
      before_action :find_receipt_template,
                    only: %i[edit update destroy preview render_preview print set_default]
    end

    # Append the gem's view prefix so bare `render :edit` resolves to the engine's templates.
    # The host's own prefixes stay first, so dropping a receipt_templates/edit.html.erb into the
    # host shadows the gem's copy without any configuration.
    def _prefixes
      @_prefixes ||= super + [VIEW_PREFIX]
    end

    def new
      @receipt_template = receipt_templates.new(default_template_attributes)
    end

    def create
      form = TemplateForm.new(receipt_template_params)

      unless form.valid?
        @errors = form.errors.full_messages
        @receipt_template = receipt_templates.new(default_template_attributes)
        return render_create_failure
      end

      @receipt_template = receipt_templates.new(form.attributes)

      if @receipt_template.save
        redirect_to after_create_path(@receipt_template),
                    notice: 'Receipt template created! Now build your layout.'
      else
        @errors = @receipt_template.errors.full_messages
        render_create_failure
      end
    end

    def edit; end

    def update
      form = TemplateForm.new(receipt_template_params)

      if form.valid?
        persist_update(form)
      else
        @errors = form.errors.full_messages
      end

      render :update, status: @errors.empty? ? :ok : :unprocessable_content
    end

    def destroy
      @receipt_template.destroy
      redirect_to after_destroy_path, notice: 'Receipt template deleted!'
    end

    def preview
      @render_result = Renderer.new(template: @receipt_template).call
    end

    def render_preview
      form = TemplateForm.new(receipt_template_params)

      @draft = @receipt_template.dup
      @draft.assign_attributes(form.attributes.except(:lock_version))

      if !form.valid?
        @render_result = nil
        @draft_errors = form.errors.full_messages
      elsif @draft.valid?
        @render_result = Renderer.new(template: @draft).call
        @draft_errors = []
      else
        @render_result = nil
        @draft_errors = @draft.errors.full_messages
      end
    end

    def print
      @render_result = Renderer.new(template: @receipt_template).call

      render :print, layout: false
    end

    def set_default
      SetDefault.new(template: @receipt_template).call

      redirect_to after_set_default_path, notice: 'Default receipt template updated!'
    end

    private

    # Hosts MUST implement this. Every query is scoped through it, which is what keeps a
    # multi-tenant host from leaking templates across tenants.
    def receipt_owner
      raise NotImplementedError, "#{self.class.name} must define #receipt_owner"
    end

    def receipt_templates
      NtiReceiptBuilder.template_class.where(owner: receipt_owner)
    end

    def find_receipt_template
      @receipt_template = receipt_templates.find_by(id: params[:id])

      redirect_to after_destroy_path, alert: 'Receipt template not found' unless @receipt_template
    end

    # The new-template form submits as a Turbo Stream, which patches the error region in place;
    # a plain HTML submit re-renders the whole form. Both carry @errors.
    def render_create_failure
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_content }
        format.html { render :new, status: :unprocessable_content }
      end
    end

    def persist_update(form)
      @receipt_template.assign_attributes(form.attributes)
      @errors = @receipt_template.save ? [] : @receipt_template.errors.full_messages
      @receipt_template.reload if @errors.empty?
    rescue ActiveRecord::StaleObjectError
      @errors = ['Someone else has already saved changes to this template. Please reload and try again.']
    end

    def receipt_template_params
      params.expect(
        receipt_template: %i[
          name paper_size_key paper_width_mm paper_height_mm orientation
          height_mode margin_top_mm margin_right_mm margin_bottom_mm
          margin_left_mm layout lock_version
        ]
      ).to_h.symbolize_keys
    end

    def default_template_attributes
      {
        paper_size_key: 'roll_80mm', paper_width_mm: 80.0, paper_height_mm: 200.0,
        orientation: 'portrait', height_mode: 'content',
        margin_top_mm: 2, margin_right_mm: 2, margin_bottom_mm: 2, margin_left_mm: 2
      }
    end

    # Overridable navigation hooks — hosts with named routes should override these.
    def after_create_path(template) = url_for(action: :edit, id: template.id)
    def after_destroy_path = url_for(action: :index)
    def after_set_default_path = url_for(action: :index)
  end
end
