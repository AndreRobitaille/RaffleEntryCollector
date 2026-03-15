import { Controller } from "@hotwired/stimulus"

// Redirects to a URL after a fixed delay. Used on the success screen
// to return to the attract screen after showing the confirmation.
export default class extends Controller {
  static values = { seconds: { type: Number, default: 90 }, redirectUrl: { type: String, default: "/" } }

  connect() {
    this.timer = setTimeout(() => {
      window.location.href = this.redirectUrlValue
    }, this.secondsValue * 1000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
