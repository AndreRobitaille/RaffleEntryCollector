import { Controller } from "@hotwired/stimulus"

// Controls the rules & drawing info modal overlay using the native <dialog> element.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  disconnect() {
    if (this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }
}
