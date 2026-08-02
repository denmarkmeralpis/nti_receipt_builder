# frozen_string_literal: true

# Stands in for whatever a host scopes receipt templates to — an account, a company, a store.
class Owner < ActiveRecord::Base
  has_many :receipt_templates,
           class_name: 'NtiReceiptBuilder::Template',
           as: :owner,
           dependent: :destroy
end
