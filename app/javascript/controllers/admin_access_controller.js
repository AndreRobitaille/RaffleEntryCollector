import { Controller } from "@hotwired/stimulus"

// Hidden admin access: 5 rapid taps on the target area OR Ctrl+Shift+A
// Navigates to the admin login page without being obvious to kiosk users
export default class extends Controller {
  static values = { url: String, taps: { type: Number, default: 5 } }

  connect() {
    this.tapCount = 0
    this.tapTimer = null
    this._handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleKeydown)
  }

  disconnect() {
    clearTimeout(this.tapTimer)
    document.removeEventListener("keydown", this._handleKeydown)
  }

  tap() {
    this.tapCount++
    clearTimeout(this.tapTimer)

    if (this.tapCount >= this.tapsValue) {
      this.tapCount = 0
      window.location.href = this.urlValue
      return
    }

    // Reset tap count after 1.5 seconds of inactivity
    this.tapTimer = setTimeout(() => { this.tapCount = 0 }, 1500)
  }

  handleKeydown(event) {
    if (event.ctrlKey && event.shiftKey && event.key === "A") {
      event.preventDefault()
      window.location.href = this.urlValue
    }
  }
}
