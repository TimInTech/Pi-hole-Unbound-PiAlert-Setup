"use strict";

const dictionaries = {
  de: {
    maintenance: "Wartung", language: "Sprache", flightplan: "Wartungs-Flugplan", openPihole: "Pi-hole öffnen", logout: "Abmelden", login: "Anmelden", apiKey: "Suite-API-Key",
    loginIntro: "Der sichere Arbeitsplatz für Pi-hole und Unbound. Prüfen, sichern und kontrolliert aktualisieren.", apiKeyHint: "Verwendet den bestehenden SUITE_API_KEY, nicht das Pi-hole-Kennwort.",
    disconnected: "Nicht verbunden", connected: "Verbunden", unreachable: "Nicht erreichbar", expired: "Sitzung abgelaufen. Bitte erneut anmelden.", loginFailed: "Anmeldung fehlgeschlagen. API-Key prüfen.", rateLimited: "Zu viele Versuche. Bitte fünf Minuten warten.",
    copyAddress: "Wartungsadresse kopieren", copied: "Wartungsadresse kopiert.", copyFailed: "Kopieren nicht möglich. Adresse aus der Browserzeile übernehmen.", overview: "Betriebsübersicht", refresh: "Neu laden", lastJob: "Letzter Auftrag", time: "Zeitpunkt", requiredChecks: "Pflichtprüfungen bestanden", system: "Systemwerte", snapshot: "Momentaufnahme des letzten Auftrags, keine Live-Messung.", checklist: "Prüfablauf", actions: "Wartung ausführen", oneJob: "Ein Auftrag zur Zeit. Sicherheitsprüfungen bleiben aktiv.",
    check: "Systemcheck", backup: "Backup", update: "Update", checkDescription: "Prüft Pi-hole, Unbound und beide DNS-Pfade. Ohne Änderungen.", backupDescription: "Sichert Konfiguration und Datenbanken. Prüft alle Dateien vor der Freigabe.", updateDescription: "Erstellt zuerst ein Backup, aktualisiert das System und prüft anschließend DNS. Kann länger dauern.", startCheck: "Systemcheck starten", startBackup: "Backup erstellen", startUpdate: "Update starten", confirmBackup: "Backup bestätigen", confirmUpdate: "Zum Bestätigen UPDATE eingeben",
    backups: "Verifizierte Backups", retention: "Maximal 10 Sicherungen", backupPrivacy: "Downloads enthalten private Konfiguration. Sicher aufbewahren. Wiederherstellung nur lokal, nicht im Browser.", noBackups: "Noch keine verifizierten Backups verfügbar.", backupsFailed: "Backupliste nicht verfügbar. Bitte neu laden.", download: "Archiv herunterladen", deleteBackup: "Backup endgültig löschen", deleteLabel: "Zum Löschen die vollständige Backup-ID eingeben", deleted: "Backup gelöscht.", deleteFailed: "Backup nicht gelöscht. Status neu laden und Bestätigung prüfen.", verified: "Verifiziert", details: "Technische Details", footer: "Lokal betrieben. Bewusst gewartet.",
    idle: "Bereit für den ersten Check", starting: "Auftrag wird gestartet", running: "Wartung läuft", succeeded: "Auftrag erfolgreich", failed: "Auftrag fehlgeschlagen", idleHint: "Starte einen Systemcheck, um den Zustand zu prüfen.", runningHint: "Der Runner arbeitet. Prüfergebnisse erscheinen nach Abschluss; keine geschätzten Fortschritte.", successHint: "Der letzte Auftrag ist abgeschlossen. Die Werte zeigen seinen Prüfzeitpunkt.", failedHint: "Mindestens ein erforderlicher Schritt ist fehlgeschlagen. Technische Details prüfen.", noSteps: "Noch keine Prüfergebnisse.", passed: "Bestanden", optionalWarning: "Optionale Warnung", stepFailed: "Fehlgeschlagen", notAvailable: "Nicht verfügbar", startFailed: "Auftrag nicht gestartet. Neu laden und erneut versuchen.", busy: "Ein Wartungsauftrag läuft bereits. Status neu laden.", forbidden: "Sicherheitsprüfung abgelehnt. Seite neu laden und erneut bestätigen.", networkError: "Verbindung unterbrochen. Neu laden, bevor ein weiterer Auftrag gestartet wird.", startTimeout: "Start noch nicht bestätigt. Status neu laden; keinen zweiten Auftrag starten.", reboot: "Neustart erforderlich. Bitte lokal einplanen.",
    host: "Host", temperature: "Temperatur", uptime: "Laufzeit", load: "Last · 1 / 5 / 15 min", memory: "RAM · genutzt / gesamt", disk: "Root-Dateisystem · genutzt / gesamt", architecture: "Architektur", operatingSystem: "Betriebssystem", kernel: "Kernel", days: "Tage",
    pihole_ftl: "Pi-hole FTL", unbound: "Unbound", dns_pihole: "DNS über Pi-hole", dns_unbound: "DNS über Unbound", apt_update: "Paketlisten aktualisieren", apt_upgrade: "Systempakete aktualisieren", pihole_update: "Pi-hole aktualisieren", pihole_gravity: "Gravity aktualisieren", completed: "Abgeschlossen", backup_failed: "Backup fehlgeschlagen", update_failed: "Update fehlgeschlagen", runner_failed: "Runner fehlgeschlagen", check_failed: "Systemcheck fehlgeschlagen",
    pihole_version: "Pi-hole-Version", unbound_version: "Unbound-Version", unbound_config: "Unbound-Konfiguration", listeners: "DNS-Ports", apt_simulation: "Paketupdate simulieren", timed_out: "Zeitüberschreitung", command_failed: "Befehl fehlgeschlagen", no_answer: "Keine DNS-Antwort", required_listener_missing: "Erforderlicher DNS-Port fehlt",
  },
  en: {
    maintenance: "Maintenance", language: "Language", flightplan: "Maintenance flight plan", openPihole: "Open Pi-hole", logout: "Sign out", login: "Sign in", apiKey: "Suite API key",
    loginIntro: "Your secure workspace for Pi-hole and Unbound. Check, back up and update with control.", apiKeyHint: "Uses the existing SUITE_API_KEY, not your Pi-hole password.",
    disconnected: "Disconnected", connected: "Connected", unreachable: "Unreachable", expired: "Session expired. Please sign in again.", loginFailed: "Sign-in failed. Check your API key.", rateLimited: "Too many attempts. Please wait five minutes.",
    copyAddress: "Copy maintenance address", copied: "Maintenance address copied.", copyFailed: "Unable to copy. Copy the address from your browser instead.", overview: "Operations overview", refresh: "Refresh", lastJob: "Last job", time: "Timestamp", requiredChecks: "Required checks passed", system: "System readings", snapshot: "Snapshot from the last job, not live telemetry.", checklist: "Check sequence", actions: "Run maintenance", oneJob: "One job at a time. Safety checks stay active.",
    check: "System check", backup: "Backup", update: "Update", checkDescription: "Checks Pi-hole, Unbound and both DNS paths. Makes no changes.", backupDescription: "Backs up configuration and databases. Verifies every file before release.", updateDescription: "Creates a backup first, updates the system, then checks DNS. May take a while.", startCheck: "Run system check", startBackup: "Create backup", startUpdate: "Start update", confirmBackup: "Confirm backup", confirmUpdate: "Type UPDATE to confirm",
    backups: "Verified backups", retention: "Up to 10 backups", backupPrivacy: "Downloads contain private configuration. Store securely. Restore locally, not in this browser.", noBackups: "No verified backups available yet.", backupsFailed: "Backup list unavailable. Please refresh.", download: "Download archive", deleteBackup: "Permanently delete backup", deleteLabel: "Enter the full backup ID to delete", deleted: "Backup deleted.", deleteFailed: "Backup not deleted. Refresh status and check the confirmation.", verified: "Verified", details: "Technical details", footer: "Locally hosted. Deliberately maintained.",
    idle: "Ready for the first check", starting: "Starting job", running: "Maintenance running", succeeded: "Job succeeded", failed: "Job failed", idleHint: "Run a system check to inspect the current state.", runningHint: "The runner is working. Check results appear on completion; progress is not estimated.", successHint: "The last job is complete. Readings reflect its check time.", failedHint: "At least one required step failed. Inspect the technical details.", noSteps: "No check results yet.", passed: "Passed", optionalWarning: "Optional warning", stepFailed: "Failed", notAvailable: "Unavailable", startFailed: "Job not started. Refresh and try again.", busy: "A maintenance job is already running. Refresh status.", forbidden: "Security check rejected. Reload the page and confirm again.", networkError: "Connection interrupted. Refresh before starting another job.", startTimeout: "Start not yet confirmed. Refresh status; do not start a second job.", reboot: "Reboot required. Please schedule locally.",
    host: "Host", temperature: "Temperature", uptime: "Uptime", load: "Load · 1 / 5 / 15 min", memory: "RAM · used / total", disk: "Root filesystem · used / total", architecture: "Architecture", operatingSystem: "Operating system", kernel: "Kernel", days: "days",
    pihole_ftl: "Pi-hole FTL", unbound: "Unbound", dns_pihole: "DNS via Pi-hole", dns_unbound: "DNS via Unbound", apt_update: "Refresh package lists", apt_upgrade: "Upgrade system packages", pihole_update: "Update Pi-hole", pihole_gravity: "Update Gravity", completed: "Completed", backup_failed: "Backup failed", update_failed: "Update failed", runner_failed: "Runner failed", check_failed: "System check failed",
    pihole_version: "Pi-hole version", unbound_version: "Unbound version", unbound_config: "Unbound configuration", listeners: "DNS ports", apt_simulation: "Simulate package upgrade", timed_out: "Timed out", command_failed: "Command failed", no_answer: "No DNS answer", required_listener_missing: "Required DNS port missing",
  },
};

let language = "de";
let csrfToken = null;
let pollTimer = null;
let lastObservedJobId = null;
let pendingStart = null;
let lastJob = { state: "idle" };
let backupEntries = [];
let busy = false;
let reachable = false;
let messageKey = "";
let loginErrorKey = "";
let backupError = false;
const POLL_INTERVAL_MS = 2000;
const PENDING_START_MAX_POLLS = 15;
const query = (selector) => document.querySelector(selector);
const translate = (key) => Object.hasOwn(dictionaries[language], key) ? dictionaries[language][key] : String(key ?? "—").replaceAll("_", " ");
const text = (selector, value) => { query(selector).textContent = value; };

function element(tag, value, className) {
  const node = document.createElement(tag);
  if (value !== undefined) node.textContent = value;
  if (className) node.className = className;
  return node;
}

function showMessage(key) {
  messageKey = key;
  text("#message", key ? translate(key) : "");
}

function controls() {
  const locked = busy || !reachable || !csrfToken;
  query("#check-button").disabled = locked;
  query("#backup-button").disabled = locked || !query("#backup-confirmed").checked;
  query("#update-button").disabled = locked || query("#update-confirmation").value !== "UPDATE";
  query("#backup-confirmed").disabled = locked;
  query("#update-confirmation").disabled = locked;
  query("#refresh-button").disabled = busy;
  for (const button of document.querySelectorAll(".delete-button")) {
    button.disabled = locked || button.previousElementSibling.value !== button.dataset.backupId;
  }
  text("#connection", translate(reachable ? "connected" : csrfToken ? "unreachable" : "disconnected"));
}

function stopPolling() {
  if (pollTimer !== null) window.clearTimeout(pollTimer);
  pollTimer = null;
}

function signedOut(errorKey = "") {
  stopPolling();
  csrfToken = null;
  pendingStart = null;
  lastObservedJobId = null;
  lastJob = { state: "idle" };
  backupEntries = [];
  busy = false;
  reachable = false;
  query("#dashboard").hidden = true;
  query("#login-panel").hidden = false;
  query("#logout-button").hidden = true;
  query("#password").value = "";
  query("#backup-confirmed").checked = false;
  query("#update-confirmation").value = "";
  loginErrorKey = errorKey;
  text("#login-error", errorKey ? translate(errorKey) : "");
  renderJob(lastJob);
  renderBackups();
  query("#password").focus();
}

async function request(path, options = {}) {
  const headers = new Headers(options.headers || {});
  if (options.method && options.method !== "GET") {
    headers.set("X-CSRF-Token", csrfToken || "");
    headers.set("Content-Type", "application/json");
  }
  const response = await fetch(path, { ...options, headers, credentials: "same-origin", cache: "no-store" });
  if (response.status === 401) signedOut("expired");
  return response;
}

function pollingDecision(job, pending) {
  const jobId = typeof job.job_id === "string" ? job.job_id : null;
  const newRunnerJob = pending !== null && (job.state === "running" || (jobId !== null && jobId !== pending.baselineJobId));
  if (pending !== null && !newRunnerJob) {
    const nextPending = { ...pending, attempts: pending.attempts + 1 };
    if (nextPending.attempts <= PENDING_START_MAX_POLLS) return { poll: true, pending: nextPending, timedOut: false };
    return { poll: false, pending: null, timedOut: true };
  }
  return { poll: job.state === "running", pending: null, timedOut: false };
}

function bytes(value) {
  return Number.isFinite(value) ? `${(value / 1073741824).toLocaleString(language, { maximumFractionDigits: 1 })} GiB` : translate("notAvailable");
}

function timestamp(value) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString(language);
}

function renderJob(job) {
  const state = pendingStart ? "starting" : job.state || "idle";
  text("#status", translate(state));
  query("#status").dataset.state = state;
  text("#job-summary", translate(state === "idle" ? "idleHint" : state === "failed" ? "failedHint" : state === "succeeded" ? "successHint" : "runningHint"));
  text("#last-action", job.action ? translate(job.action) : "—");
  text("#last-time", timestamp(job.finished_at || job.started_at));
  const steps = Array.isArray(job.steps) ? job.steps : [];
  const required = steps.filter((step) => step.required);
  text("#required-count", required.length ? `${required.filter((step) => step.ok).length} / ${required.length}` : "—");
  text("#job-result", JSON.stringify(job, null, 2));
  const system = job.result?.system || {};
  const memory = system.memory;
  const disk = system.root_filesystem;
  const values = [
    ["host", system.host], ["temperature", Number.isFinite(system.temperature_celsius) ? `${system.temperature_celsius.toLocaleString(language)} °C` : null],
    ["uptime", Number.isFinite(system.uptime_seconds) ? `${Math.floor(system.uptime_seconds / 86400)} ${translate("days")} ${Math.floor(system.uptime_seconds / 3600) % 24} h` : null],
    ["load", system.load_average?.map((value) => Number(value).toLocaleString(language, { maximumFractionDigits: 2 })).join(" / ")],
    ["memory", Number.isFinite(memory?.total_bytes) && Number.isFinite(memory?.available_bytes) ? `${bytes(memory.total_bytes - memory.available_bytes)} / ${bytes(memory.total_bytes)}` : null],
    ["disk", disk ? `${bytes(disk.used_bytes)} / ${bytes(disk.total_bytes)}` : null],
    ["architecture", system.architecture], ["operatingSystem", system.operating_system], ["kernel", system.kernel],
  ];
  query("#system-metrics").replaceChildren(...values.map(([key, value]) => {
    const row = element("div");
    row.append(element("dt", translate(key)), element("dd", value ?? translate("notAvailable")));
    return row;
  }));
  const rows = steps.map((step) => {
    const row = element("li");
    row.append(element("span", translate(step.name)), element("span", translate(step.ok ? "passed" : step.required ? "stepFailed" : "optionalWarning"), `step-state ${step.ok ? "passed" : step.required ? "error" : "warning"}`));
    return row;
  });
  if (!rows.length) rows.push(element("li", translate(state === "running" || state === "starting" ? "runningHint" : "noSteps"), "muted"));
  query("#step-list").replaceChildren(...rows);
  if (job.result?.reboot_required) showMessage("reboot");
  controls();
}

function renderBackups() {
  const rows = backupEntries.map((entry) => {
    const row = element("article", undefined, "backup-row");
    const info = element("div");
    info.append(element("strong", `${timestamp(entry.created_at)} · ${bytes(entry.size)} · ${translate("verified")}`), element("code", entry.backup_id), element("code", `SHA-256: ${entry.sha256}`));
    const link = element("a", translate("download"));
    link.href = `/api/maintenance/backups/${encodeURIComponent(entry.backup_id)}/download`;
    info.append(link);
    const form = element("form");
    const input = element("input");
    input.type = "text";
    input.autocomplete = "off";
    input.id = `delete-${entry.backup_id}`;
    const label = element("label", translate("deleteLabel"));
    label.htmlFor = input.id;
    const button = element("button", translate("deleteBackup"), "delete-button danger");
    button.type = "submit";
    button.dataset.backupId = entry.backup_id;
    input.addEventListener("input", controls);
    form.append(label, input, button);
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (busy || !reachable || input.value !== entry.backup_id) return;
      busy = true;
      controls();
      try {
        const response = await request(`/api/maintenance/backups/${encodeURIComponent(entry.backup_id)}`, { method: "DELETE", body: JSON.stringify({ confirmation: input.value }) });
        if (response.status === 401) return;
        showMessage(response.ok ? "deleted" : response.status === 409 ? "busy" : "deleteFailed");
        await loadBackups();
        query("#backups-heading").setAttribute("tabindex", "-1");
        query("#backups-heading").focus();
      } catch { connectionLost(); }
      finally { busy = false; controls(); }
    });
    row.append(info, form);
    return row;
  });
  if (!rows.length) rows.push(element("p", translate(backupError ? "backupsFailed" : "noBackups"), "muted"));
  query("#backup-list").replaceChildren(...rows);
  controls();
}

async function loadBackups() {
  try {
    const response = await request("/api/maintenance/backups");
    if (response.status === 401) return;
    backupError = !response.ok;
    backupEntries = response.ok ? await response.json() : [];
  } catch { backupError = true; backupEntries = []; }
  renderBackups();
}

function connectionLost() {
  stopPolling();
  pendingStart = null;
  busy = false;
  reachable = false;
  showMessage("networkError");
  text("#status", translate("unreachable"));
  query("#status").dataset.state = "failed";
  controls();
}

async function refreshStatus() {
  stopPolling();
  try {
    const response = await request("/api/maintenance/status");
    if (response.status === 401) return;
    if (!response.ok) { connectionLost(); return; }
    lastJob = await response.json();
    if (!csrfToken) return;
    reachable = true;
    if (typeof lastJob.job_id === "string") lastObservedJobId = lastJob.job_id;
    const decision = pollingDecision(lastJob, pendingStart);
    pendingStart = decision.pending;
    busy = decision.poll;
    renderJob(lastJob);
    if (decision.timedOut) { reachable = false; showMessage("startTimeout"); controls(); }
    if (decision.poll) pollTimer = window.setTimeout(refreshStatus, POLL_INTERVAL_MS);
    else await loadBackups();
  } catch { connectionLost(); }
}

async function startAction(action) {
  if (busy || !reachable) return;
  if (action === "backup" && !query("#backup-confirmed").checked) return;
  if (action === "update" && query("#update-confirmation").value !== "UPDATE") return;
  busy = true;
  controls();
  showMessage("");
  pendingStart = { baselineJobId: lastObservedJobId, attempts: 0 };
  renderJob(lastJob);
  try {
    const body = action === "backup" ? { confirmed: true } : action === "update" ? { confirmation: "UPDATE" } : {};
    const response = await request(`/api/maintenance/${action}`, { method: "POST", body: JSON.stringify(body) });
    if (response.status === 401) return;
    if (!response.ok) {
      pendingStart = null;
      busy = false;
      showMessage(response.status === 409 ? "busy" : response.status === 403 ? "forbidden" : "startFailed");
      await refreshStatus();
      return;
    }
    query("#backup-confirmed").checked = false;
    query("#update-confirmation").value = "";
    await refreshStatus();
  } catch { connectionLost(); }
}

function changeLanguage(value) {
  language = value === "en" ? "en" : "de";
  document.documentElement.lang = language;
  document.title = `Pi-hole · ${translate("flightplan")}`;
  query("#language").value = language;
  for (const node of document.querySelectorAll("[data-i18n]")) node.textContent = translate(node.dataset.i18n);
  text("#login-error", loginErrorKey ? translate(loginErrorKey) : "");
  showMessage(messageKey);
  renderJob(lastJob);
  renderBackups();
}

async function signedIn(payload) {
    csrfToken = payload.csrf_token;
    if (typeof payload.pihole_url === "string" && /^https?:\/\//.test(payload.pihole_url)) query("#pihole-link").href = payload.pihole_url;
  query("#login-panel").hidden = true;
  query("#dashboard").hidden = false;
  query("#logout-button").hidden = false;
  loginErrorKey = "";
  showMessage("");
  query("#dashboard-heading").focus();
  await refreshStatus();
}

function initialize() {
  let stored;
  try { stored = localStorage.getItem("maintenance-language"); } catch { stored = null; }
  changeLanguage(stored === "de" || stored === "en" ? stored : navigator.language.startsWith("de") ? "de" : "en");
  query("#pihole-link").href = `http://${window.location.hostname}/admin/`;
  query("#language").addEventListener("change", (event) => {
    changeLanguage(event.target.value);
    try { localStorage.setItem("maintenance-language", language); } catch {}
  });
  query("#login-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const password = query("#password").value;
    query("#password").value = "";
    query("#login-button").disabled = true;
    try {
      const response = await fetch("/api/session", { method: "POST", headers: { "Content-Type": "application/json" }, credentials: "same-origin", body: JSON.stringify({ password }) });
      if (!response.ok) {
        loginErrorKey = response.status === 429 ? "rateLimited" : "loginFailed";
        text("#login-error", translate(loginErrorKey));
        query("#password").focus();
      } else await signedIn(await response.json());
    } catch { loginErrorKey = "networkError"; text("#login-error", translate(loginErrorKey)); }
    finally { query("#login-button").disabled = false; }
  });
  for (const action of ["check", "backup", "update"]) query(`#${action}-button`).addEventListener("click", () => startAction(action));
  query("#backup-confirmed").addEventListener("change", controls);
  query("#update-confirmation").addEventListener("input", controls);
  query("#refresh-button").addEventListener("click", () => { showMessage(""); refreshStatus(); });
  query("#copy-address").addEventListener("click", async () => {
    try { await navigator.clipboard.writeText(window.location.origin + "/"); showMessage("copied"); }
    catch { showMessage("copyFailed"); }
  });
  query("#logout-button").addEventListener("click", async () => {
    try {
      const response = await request("/api/session/logout", { method: "POST" });
      if (response.ok || response.status === 401) signedOut();
      else showMessage("forbidden");
    } catch { connectionLost(); }
  });
  fetch("/api/session", { credentials: "same-origin", cache: "no-store" })
    .then(async (response) => { if (response.ok) await signedIn(await response.json()); })
    .catch(() => { loginErrorKey = "networkError"; text("#login-error", translate(loginErrorKey)); });
}

document.addEventListener("DOMContentLoaded", initialize);
