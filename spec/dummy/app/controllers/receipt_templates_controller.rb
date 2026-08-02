# frozen_string_literal: true

# The minimal host controller: routing, tenancy, and nothing else.
class ReceiptTemplatesController < ActionController::Base
  include NtiReceiptBuilder::TemplatesController

  def index
    render plain: receipt_templates.order(:name).map(&:name).join(',')
  end

  private

  def receipt_owner = Owner.first
end
