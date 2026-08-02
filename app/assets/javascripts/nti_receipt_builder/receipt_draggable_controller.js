import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nrb-draggable"
export default class extends Controller {
  static values = {
    elementId: String,
    xMm: Number,
    yMm: Number,
    widthMm: Number,
    heightMm: Number
  }

  static targets = ["resizeHandle"]
  static outlets = ["nrb-canvas"]

  // A gesture interrupted by navigation never reaches dragEnd/resizeEnd, so its cleanup path
  // never runs and pointer capture is never released. Tear both down here.
  disconnect() {
    this.teardownDrag()
    this.teardownResize()
  }

  teardownDrag() {
    if (!this.boundDragMove) return

    this.element.removeEventListener("pointermove", this.boundDragMove)
    this.element.removeEventListener("pointerup", this.boundDragEnd)
    this.element.removeEventListener("pointercancel", this.boundDragEnd)
    this.element.classList.remove("nrb-receipt-element-dragging")
    this.boundDragMove = null
    this.boundDragEnd = null
    this.dragOrigin = null
  }

  teardownResize() {
    if (!this.boundResizeMove) return

    if (this.hasResizeHandleTarget) {
      this.resizeHandleTarget.removeEventListener("pointermove", this.boundResizeMove)
      this.resizeHandleTarget.removeEventListener("pointerup", this.boundResizeEnd)
      this.resizeHandleTarget.removeEventListener("pointercancel", this.boundResizeEnd)
    }
    this.element.classList.remove("nrb-receipt-element-resizing")
    this.boundResizeMove = null
    this.boundResizeEnd = null
    this.resizeOrigin = null
  }

  dragStart(event) {
    if (event.button !== 0) return
    event.preventDefault()
    event.stopPropagation()

    this.dragOrigin = { clientX: event.clientX, clientY: event.clientY, xMm: this.xMmValue, yMm: this.yMmValue }
    this.element.setPointerCapture(event.pointerId)
    this.boundDragMove = this.dragMove.bind(this)
    this.boundDragEnd = this.dragEnd.bind(this)
    this.element.addEventListener("pointermove", this.boundDragMove)
    this.element.addEventListener("pointerup", this.boundDragEnd)
    this.element.addEventListener("pointercancel", this.boundDragEnd)
    this.element.classList.add("nrb-receipt-element-dragging")
    this.dispatchSelected()
  }

  dragMove(event) {
    if (!this.dragOrigin || !this.hasNrbCanvasOutlet) return

    const canvas = this.nrbCanvasOutlet
    const deltaXMm = canvas.toMm(event.clientX - this.dragOrigin.clientX)
    const deltaYMm = canvas.toMm(event.clientY - this.dragOrigin.clientY)
    const snappedX = canvas.snap(this.dragOrigin.xMm + deltaXMm)
    const snappedY = canvas.snap(this.dragOrigin.yMm + deltaYMm)
    const { xMm, yMm } = canvas.clampPosition(snappedX, snappedY, this.widthMmValue, this.heightMmValue)

    this.xMmValue = xMm
    this.yMmValue = yMm
    this.applyPosition()
  }

  dragEnd(event) {
    if (!this.dragOrigin) return

    this.element.releasePointerCapture(event.pointerId)
    const detail = { id: this.elementIdValue, xMm: this.xMmValue, yMm: this.yMmValue }
    this.teardownDrag()

    this.dispatch("moved", { prefix: "receipt-element", bubbles: true, detail })
  }

  resizeStart(event) {
    if (event.button !== 0) return
    event.preventDefault()
    event.stopPropagation()

    this.resizeOrigin = {
      clientX: event.clientX,
      clientY: event.clientY,
      widthMm: this.widthMmValue,
      heightMm: this.heightMmValue,
      xMm: this.xMmValue,
      yMm: this.yMmValue
    }
    this.resizeHandleTarget.setPointerCapture(event.pointerId)
    this.boundResizeMove = this.resizeMove.bind(this)
    this.boundResizeEnd = this.resizeEnd.bind(this)
    this.resizeHandleTarget.addEventListener("pointermove", this.boundResizeMove)
    this.resizeHandleTarget.addEventListener("pointerup", this.boundResizeEnd)
    this.resizeHandleTarget.addEventListener("pointercancel", this.boundResizeEnd)
    this.element.classList.add("nrb-receipt-element-resizing")
    this.dispatchSelected()
  }

  resizeMove(event) {
    if (!this.resizeOrigin || !this.hasNrbCanvasOutlet) return

    const canvas = this.nrbCanvasOutlet
    const deltaWidthMm = canvas.toMm(event.clientX - this.resizeOrigin.clientX)
    const deltaHeightMm = canvas.toMm(event.clientY - this.resizeOrigin.clientY)
    const rawWidth = canvas.snap(this.resizeOrigin.widthMm + deltaWidthMm)
    const rawHeight = canvas.snap(this.resizeOrigin.heightMm + deltaHeightMm)
    const { widthMm, heightMm } = canvas.clampSize(rawWidth, rawHeight, this.resizeOrigin.xMm, this.resizeOrigin.yMm)

    this.widthMmValue = widthMm
    this.heightMmValue = heightMm
    this.applyPosition()
  }

  resizeEnd(event) {
    if (!this.resizeOrigin) return

    this.resizeHandleTarget.releasePointerCapture(event.pointerId)
    const detail = {
      id: this.elementIdValue,
      xMm: this.xMmValue,
      yMm: this.yMmValue,
      widthMm: this.widthMmValue,
      heightMm: this.heightMmValue
    }
    this.teardownResize()

    this.dispatch("resized", { prefix: "receipt-element", bubbles: true, detail })
  }

  dispatchSelected() {
    this.dispatch("selected", { prefix: "receipt-element", bubbles: true, detail: { id: this.elementIdValue } })
  }

  applyPosition() {
    this.element.style.left = `${this.xMmValue}mm`
    this.element.style.top = `${this.yMmValue}mm`
    this.element.style.width = `${this.widthMmValue}mm`
    this.element.style.height = `${this.heightMmValue}mm`
  }
}
