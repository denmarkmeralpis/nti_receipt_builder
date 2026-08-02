import ReceiptBuilderController from "nti_receipt_builder/receipt_builder_controller"
import ReceiptCanvasController from "nti_receipt_builder/receipt_canvas_controller"
import ReceiptDraggableController from "nti_receipt_builder/receipt_draggable_controller"
import ReceiptPrintController from "nti_receipt_builder/receipt_print_controller"
import ReceiptPropertiesController from "nti_receipt_builder/receipt_properties_controller"

// Identifiers are registered explicitly rather than derived from file paths, so they stay short
// and stable regardless of where a host mounts the gem's JavaScript. They must match the
// data-controller attributes in the gem's views.
export function registerNtiReceiptBuilder(application) {
  application.register("nrb-builder", ReceiptBuilderController)
  application.register("nrb-canvas", ReceiptCanvasController)
  application.register("nrb-draggable", ReceiptDraggableController)
  application.register("nrb-print", ReceiptPrintController)
  application.register("nrb-properties", ReceiptPropertiesController)
}
