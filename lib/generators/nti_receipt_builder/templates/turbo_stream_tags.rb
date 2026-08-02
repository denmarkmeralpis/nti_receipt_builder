# frozen_string_literal: true

# The Turbo Stream actions nti_receipt_builder's views emit. Pair them with matching
# turbo_stream action handlers in your JavaScript (app_modal, close_modal, toast,
# reload_datatable). Delete this file if your application already provides them.
Turbo::Streams::TagBuilder.class_eval do
  def open_modal(size: 'modal-md', &)
    content = @view_context.capture(&)

    @view_context.turbo_stream_action_tag(
      :app_modal,
      size: size,
      template: content
    )
  end

  def close_modal
    @view_context.turbo_stream_action_tag(:close_modal)
  end

  def toast(message, type: :success)
    @view_context.turbo_stream_action_tag(
      :toast,
      message: message,
      type: type
    )
  end

  def reload_datatable(table_id, url: nil)
    @view_context.turbo_stream_action_tag(
      :reload_datatable,
      'table-id': table_id,
      url: url
    )
  end
end
