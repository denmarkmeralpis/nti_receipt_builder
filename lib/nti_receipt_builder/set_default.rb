# frozen_string_literal: true

module NtiReceiptBuilder
  # Makes one template the owner's default, clearing any previous default in a single UPDATE
  # rather than loading the collection.
  class SetDefault
    def initialize(template:)
      @template = template
    end

    def call
      template.class
              .where(owner_type: template.owner_type, owner_id: template.owner_id, is_default: true)
              .where.not(id: template.id)
              .update_all(is_default: false, updated_at: Time.current)

      template.update!(is_default: true) unless template.is_default?
    end

    private

    attr_reader :template
  end
end
