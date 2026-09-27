// Landing page interactivity: the overpayment calculator and lead-source capture.
// Pure client-side — no server round-trips needed for the sliders.

// Plausible queue stub: analytics loads async, so queue events fired before it's ready.
window.plausible =
  window.plausible ||
  function () {
    ;(window.plausible.q = window.plausible.q || []).push(arguments)
  }

// Fire a Plausible custom event at most once per page load.
function trackOnce(name) {
  trackOnce.fired = trackOnce.fired || {}
  if (trackOnce.fired[name]) return
  trackOnce.fired[name] = true
  window.plausible(name)
}

function initLanding() {
  const cena = document.getElementById("cena")
  const metry = document.getElementById("metry")
  const cenaVal = document.getElementById("cena-val")
  const metryVal = document.getElementById("metry-val")
  const wynik = document.getElementById("wynik")
  const estimateField = document.getElementById("estimate-field")
  const priceField = document.getElementById("price-field")
  const wallField = document.getElementById("wall-field")
  const sourceField = document.getElementById("source-field")

  const fmt = (n) => n.toLocaleString("pl-PL") + " zł"

  const paintRange = (el) => {
    const pct = ((el.value - el.min) / (el.max - el.min)) * 100
    el.style.setProperty("--fill", pct + "%")
  }

  const recalc = () => {
    if (!cena || !metry) return
    const priceLabel = fmt(+cena.value)
    const wallLabel = (+metry.value).toLocaleString("pl-PL") + " m²"
    cenaVal.textContent = priceLabel
    metryVal.textContent = wallLabel
    const result = fmt(Math.round(cena.value * metry.value))
    wynik.textContent = result
    if (estimateField) estimateField.value = result
    if (priceField) priceField.value = priceLabel
    if (wallField) wallField.value = wallLabel
    paintRange(cena)
    paintRange(metry)
  }

  if (cena && metry) {
    ;[cena, metry].forEach((el) => {
      el.addEventListener("input", recalc)
      // Track calculator interaction once (sliders aren't clicks, so tagged-events miss them)
      el.addEventListener("input", () => trackOnce("Kalkulator"), { once: true })
    })
    recalc()
  }

  // Track when the visitor scrolls the lead form into view (funnel mid-step).
  const formSection = document.getElementById("zgloszenie")
  if (formSection && "IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            trackOnce("Scroll Formularz")
            observer.disconnect()
          }
        })
      },
      { threshold: 0.3 }
    )
    observer.observe(formSection)
  }

  // Capture where the lead came from (utm_source or referrer) for the hidden field.
  if (sourceField && !sourceField.value) {
    const utm = new URLSearchParams(location.search).get("utm_source")
    sourceField.value = utm || document.referrer || "direct"
  }

  // Submit the lead form via fetch so the URL never changes and we can toggle
  // the success box in place (instead of a full-page redirect).
  const form = document.getElementById("leadForm")
  const successBox = document.getElementById("successBox")
  const successClose = document.getElementById("successClose")

  const clearErrors = () => {
    if (form) form.querySelectorAll(".js-field-err").forEach((el) => el.remove())
  }

  // Render per-field validation errors returned by the server (JSON:
  // { field: ["message", ...] }), matching the inline .field-err styling.
  const showErrors = (errors) => {
    clearErrors()
    let firstErr = null
    Object.entries(errors || {}).forEach(([field, msgs]) => {
      const input = form.querySelector(`[name="lead[${field}]"]`)
      if (!input || !msgs || !msgs.length) return
      const p = document.createElement("p")
      p.className = "field-err js-field-err"
      p.textContent = msgs[0]
      const container = input.closest(".field")
      if (container) container.appendChild(p)
      else (input.closest(".consent") || input).insertAdjacentElement("afterend", p)
      firstErr = firstErr || p
    })
    if (firstErr) firstErr.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  if (form && successBox) {
    const submitBtn = form.querySelector("#submitBtn")

    form.addEventListener("submit", async (e) => {
      e.preventDefault()
      clearErrors()
      if (submitBtn) submitBtn.disabled = true

      try {
        const token = document.querySelector('meta[name="csrf-token"]')
        const res = await fetch(form.action, {
          method: "POST",
          headers: token ? { "x-csrf-token": token.content } : {},
          body: new FormData(form),
        })

        if (res.ok) {
          form.style.display = "none"
          successBox.style.display = "block"
          successBox.scrollIntoView({ behavior: "smooth", block: "center" })
        } else if (res.status === 422) {
          const data = await res.json().catch(() => ({}))
          showErrors(data.errors)
        } else {
          showErrors({ email: ["Nie udało się wysłać zgłoszenia. Spróbuj ponownie."] })
        }
      } catch (_err) {
        showErrors({ email: ["Brak połączenia. Spróbuj ponownie."] })
      } finally {
        if (submitBtn) submitBtn.disabled = false
      }
    })
  }

  // Close button on the success box: hide it, restore a fresh form.
  if (successClose && successBox && form) {
    successClose.addEventListener("click", () => {
      successBox.style.display = "none"
      form.style.display = ""
      clearErrors()
      form.reset()
      recalc()
    })
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initLanding)
} else {
  initLanding()
}
