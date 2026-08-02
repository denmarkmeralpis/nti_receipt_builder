# frozen_string_literal: true

NtiReceiptBuilder.configure do |config|
  # Required. A NtiReceiptBuilder::Variables subclass declaring this application's receipt
  # placeholders. Assign the class or its name — the gem stores only the name, so a reloadable
  # application class is never pinned across a code reload.
  # config.variables_class = 'OrderReceiptVariables'

  # Optional. Point at a subclass of NtiReceiptBuilder::Template to attach your own concerns
  # (audit, status, tenancy) while sharing the same table.
  # config.template_class = 'ReceiptTemplate'

  # Optional formatting.
  # config.currency_unit   = '₱'
  # config.datetime_format = '%m/%d/%Y %I:%M %p'
end
