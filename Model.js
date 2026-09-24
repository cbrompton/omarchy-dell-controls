function parseKeyValue(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf("\t")
    if (idx <= 0) continue
    next[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
  }
  return next
}

function words(value) {
  return String(value || "").split(/\s+/).filter(function(w) { return w !== "" })
}

function capitalize(value) {
  var s = String(value || "")
  return s.charAt(0).toUpperCase() + s.slice(1)
}

function healthPercent(info) {
  var tenths = Number(info.health_pct)
  return isFinite(tenths) && tenths > 0 ? (tenths / 10).toFixed(1) + "%" : "—"
}

function temp(value) {
  return value !== undefined && value !== "" ? value + "°C" : "—"
}

var chargeTypeInfo = {
  Standard: { icon: "󰂄", tooltip: "Charge fully at a normal rate" },
  Adaptive: { icon: "󰚥", tooltip: "Firmware picks thresholds from your usage" },
  Custom: { icon: "󰂏", tooltip: "Charge between the start and stop limits below" },
  Fast: { icon: "󱐋", tooltip: "Fastest charging, most battery wear" },
  Trickle: { icon: "󰢟", tooltip: "Slow charging, for always-plugged-in use" },
  PrimAcUse: { icon: "󰚥", tooltip: "Mostly on AC" }
}

var chargeTypeOrder = ["Standard", "Adaptive", "Custom", "Fast", "Trickle", "PrimAcUse"]

// Labels only (no icons) so all five firmware modes fit on one row.
function chargeTypeOptions(info) {
  return words(info.charge_types).sort(function(a, b) {
    var ia = chargeTypeOrder.indexOf(a), ib = chargeTypeOrder.indexOf(b)
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib)
  }).map(function(t) {
    var meta = chargeTypeInfo[t] || {}
    return { value: t, label: t, tooltip: meta.tooltip || "" }
  })
}

var thermalInfo = {
  cool: { icon: "󰜗", label: "Cool", tooltip: "Keeps the chassis cool, lowers performance" },
  quiet: { icon: "󰖀", label: "Quiet", tooltip: "Lower fan noise, lowers performance" },
  balanced: { icon: "󰊚", label: "Optimized", tooltip: "Dell's default balance of fan, heat and speed" },
  performance: { icon: "󰓅", label: "Ultra", tooltip: "Maximum performance, louder fans" },
  "low-power": { icon: "󰌪", label: "Low power", tooltip: "Lowest power draw" }
}

function thermalOptions(info) {
  return words(info.thermal_choices).map(function(p) {
    var meta = thermalInfo[p] || {}
    return { value: p, label: meta.label || capitalize(p), icon: meta.icon || "", tooltip: meta.tooltip || "" }
  })
}

var fanOptions = [
  { value: "auto", label: "Auto", icon: "󰈐", tooltip: "BIOS controls the fans (follows the thermal profile)" },
  { value: "medium", label: "Medium", icon: "󱑳", tooltip: "Fixed medium speed. Returns to Auto if the CPU reaches 85°C" },
  { value: "max", label: "Max", icon: "󱑴", tooltip: "Both fans at full speed" }
]

function fanSummary(info) {
  var parts = []
  for (var i = 1; i <= 2; i++) {
    if (info["fan" + i + "_rpm"] === undefined) continue
    parts.push(info["fan" + i + "_rpm"])
  }
  return parts.length ? parts.join(" / ") + " RPM" : ""
}

// Dell firmware accepts start 50–95 and end 55–100 in steps of 5, with end at
// least 5 above start. Moving one slider nudges the other to keep that true.
function chargeWindow(start, end, which, value) {
  if (which === "start") return { start: value, end: Math.max(end, value + 5) }
  return { start: Math.min(start, value - 5), end: value }
}

function chargeLimitSummary(info) {
  if (info.charge_type !== "Custom" || !info.charge_end) return "No charge limit in " + (info.charge_type || "this") + " mode — set one below"
  return "Charges to " + info.charge_end + "%, resumes below " + info.charge_start + "%"
}

function gpuStateLabel(state) {
  if (state === "suspended") return "Asleep"
  if (state === "active") return "Awake"
  return capitalize(state || "unknown")
}

if (typeof module !== "undefined") {
  module.exports = {
    parseKeyValue: parseKeyValue,
    words: words,
    healthPercent: healthPercent,
    chargeTypeOptions: chargeTypeOptions,
    thermalOptions: thermalOptions,
    fanOptions: fanOptions,
    fanSummary: fanSummary,
    chargeWindow: chargeWindow,
    chargeLimitSummary: chargeLimitSummary,
    gpuStateLabel: gpuStateLabel
  }
}
