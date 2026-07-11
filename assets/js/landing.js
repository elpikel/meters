// Landing page interactivity: the overpayment calculator and lead-source capture.
// Pure client-side — no server round-trips needed for the sliders.

function initLanding() {
  const cena = document.getElementById("cena")
  const metry = document.getElementById("metry")
  const cenaVal = document.getElementById("cena-val")
  const metryVal = document.getElementById("metry-val")
  const wynik = document.getElementById("wynik")
  const estimateField = document.getElementById("estimate-field")
  const sourceField = document.getElementById("source-field")

  const fmt = (n) => n.toLocaleString("pl-PL") + " zł"

  const paintRange = (el) => {
    const pct = ((el.value - el.min) / (el.max - el.min)) * 100
    el.style.setProperty("--fill", pct + "%")
  }

  const recalc = () => {
    if (!cena || !metry) return
    cenaVal.textContent = fmt(+cena.value)
    metryVal.textContent = (+metry.value).toLocaleString("pl-PL") + " m²"
    const result = fmt(Math.round(cena.value * metry.value))
    wynik.textContent = result
    if (estimateField) estimateField.value = result
    paintRange(cena)
    paintRange(metry)
  }

  if (cena && metry) {
    ;[cena, metry].forEach((el) => el.addEventListener("input", recalc))
    recalc()
  }

  // Capture where the lead came from (utm_source or referrer) for the hidden field.
  if (sourceField && !sourceField.value) {
    const utm = new URLSearchParams(location.search).get("utm_source")
    sourceField.value = utm || document.referrer || "direct"
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initLanding)
} else {
  initLanding()
}
