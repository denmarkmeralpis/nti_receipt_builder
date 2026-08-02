import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nrb-print"
export default class extends Controller {
  static values = { auto: { type: Boolean, default: true } }

  connect() {
    if (!this.autoValue) return

    // Cancelled on disconnect: an un-cancelled frame fires window.print() after the element is
    // gone, which surfaces a print dialog over whatever the user navigated to.
    this.printFrame = requestAnimationFrame(() => {
      this.printFrame = null
      window.print()
    })
  }

  disconnect() {
    if (!this.printFrame) return

    cancelAnimationFrame(this.printFrame)
    this.printFrame = null
  }
}
