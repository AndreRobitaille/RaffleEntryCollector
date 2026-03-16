import { Controller } from "@hotwired/stimulus"

// Controls the Sponsor / Vendor exclusion and reinstatement modal dialogs.
// Fetches company match data, shows preview, and handles "type all" confirmation.
export default class extends Controller {
  static targets = ["dialog", "preview", "count", "list", "more",
                     "confirmInput", "bulkButton", "companyName"]
  static values = {
    matchesUrl: String,
    context: String
  }

  open() {
    this.fetchMatches()
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
    this.resetConfirmation()
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

  async fetchMatches() {
    try {
      const url = `${this.matchesUrlValue}?context=${this.contextValue}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()
      this.populatePreview(data)
    } catch (error) {
      this.previewTarget.style.display = "none"
    }
  }

  populatePreview(data) {
    if (data.count <= 1) {
      this.previewTarget.style.display = "none"
      return
    }

    this.previewTarget.style.display = ""
    this.countTarget.textContent = `${data.count} entries from ${data.company}`

    this.listTarget.innerHTML = ""
    data.entries.forEach(entry => {
      const li = document.createElement("li")
      li.textContent = `${entry.first_name} ${entry.last_name} — ${entry.email}`
      this.listTarget.appendChild(li)
    })

    if (data.count > 3) {
      this.moreTarget.textContent = `+ ${data.count - 3} more`
      this.moreTarget.style.display = ""
    } else {
      this.moreTarget.style.display = "none"
    }

    if (this.hasCompanyNameTarget) {
      this.companyNameTargets.forEach(el => {
        el.textContent = data.company
      })
    }
  }

  validateConfirmation() {
    const input = this.confirmInputTarget.value.trim().toLowerCase()
    if (input === "all") {
      this.bulkButtonTarget.disabled = false
      this.bulkButtonTarget.classList.remove("admin-btn--disabled")
    } else {
      this.bulkButtonTarget.disabled = true
      this.bulkButtonTarget.classList.add("admin-btn--disabled")
    }
  }

  resetConfirmation() {
    if (this.hasConfirmInputTarget) {
      this.confirmInputTarget.value = ""
    }
    if (this.hasBulkButtonTarget) {
      this.bulkButtonTarget.disabled = true
      this.bulkButtonTarget.classList.add("admin-btn--disabled")
    }
  }
}
