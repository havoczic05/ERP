import { Controller } from "@hotwired/stimulus"

// Mobile-only floating action button: double-tap to act.
//
// On a phone the primary "Nuevo …" button is repositioned by CSS as a circular
// FAB showing only its icon. The FIRST tap reveals the label (arms the button);
// a SECOND tap while armed lets the link's default action proceed (navigate, or
// open the Turbo modal). It auto-disarms after a moment, on a tap elsewhere, or
// on Turbo navigation. On desktop (`isMobile` false) it's a normal single click.
export default class extends Controller {
  connect() {
    this.armed = false
    this.onOutside = (event) => { if (!this.element.contains(event.target)) this.disarm() }
    this.onNavigate = () => this.disarm()
    document.addEventListener("turbo:before-render", this.onNavigate)
  }

  disconnect() {
    document.removeEventListener("click", this.onOutside)
    document.removeEventListener("turbo:before-render", this.onNavigate)
    clearTimeout(this.timer)
  }

  click(event) {
    if (!this.isMobile) return   // desktop: normal single click
    if (this.armed) return       // armed: let the link's default proceed
    event.preventDefault()
    this.arm()
  }

  arm() {
    this.armed = true
    this.element.classList.add("is-armed")
    document.addEventListener("click", this.onOutside)
    this.timer = setTimeout(() => this.disarm(), 2500)
  }

  disarm() {
    this.armed = false
    this.element.classList.remove("is-armed")
    document.removeEventListener("click", this.onOutside)
    clearTimeout(this.timer)
  }

  get isMobile() {
    return window.matchMedia("(max-width: 640px)").matches
  }
}
