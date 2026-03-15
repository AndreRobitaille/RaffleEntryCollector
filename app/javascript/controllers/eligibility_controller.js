import { Controller } from "@hotwired/stimulus"

// Manages the eligibility checkbox gate on the entry form.
// When the checkbox is unchecked, all form fields and the submit button are disabled.
export default class extends Controller {
  static targets = ["checkbox", "field", "submit"]

  connect() {
    this.toggle()
  }

  toggle() {
    const enabled = this.checkboxTarget.checked
    this.fieldTargets.forEach(field => field.disabled = !enabled)
    this.submitTarget.disabled = !enabled
  }
}
