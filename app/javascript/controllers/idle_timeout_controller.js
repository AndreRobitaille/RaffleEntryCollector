import { Controller } from "@hotwired/stimulus"

// Resets the kiosk to the attract screen after a period of inactivity.
// Listens for input events (touch, key, mouse) and resets the timer on activity.
export default class extends Controller {
  static values = { seconds: { type: Number, default: 90 }, redirectUrl: { type: String, default: "/" } }

  connect() {
    this.boundReset = this.resetTimer.bind(this)
    this.events = ["touchstart", "mousedown", "keydown", "input", "click"]

    this.events.forEach(event => {
      document.addEventListener(event, this.boundReset)
    })

    this.resetTimer()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.events.forEach(event => {
      document.removeEventListener(event, this.boundReset)
    })
  }

  resetTimer() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      window.location.href = this.redirectUrlValue
    }, this.secondsValue * 1000)
  }
}
