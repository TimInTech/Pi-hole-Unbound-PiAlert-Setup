"use strict";

let csrfToken = null;
let pollTimer = null;
let lastObservedJobId = null;
let pendingStart = null;

const POLL_INTERVAL_MS = 2000;
const PENDING_START_MAX_POLLS = 15;

const loginPanel = document.querySelector("#login-panel");
const dashboard = document.querySelector("#dashboard");
const statusText = document.querySelector("#status");
const resultText = document.querySelector("#job-result");

function showMessage(message) {
  statusText.textContent = message;
}

async function request(path, options = {}) {
  const headers = new Headers(options.headers || {});
  if (options.method && options.method !== "GET") {
    headers.set("Origin", window.location.origin);
    headers.set("X-CSRF-Token", csrfToken || "");
  }
  return fetch(path, { ...options, headers, credentials: "same-origin" });
}

function stopPolling() {
  if (pollTimer !== null) {
    window.clearTimeout(pollTimer);
    pollTimer = null;
  }
}

function pollingDecision(job, pending) {
  const jobId = typeof job.job_id === "string" ? job.job_id : null;
  const newRunnerJob = pending !== null && (
    job.state === "running" || (jobId !== null && jobId !== pending.baselineJobId)
  );
  if (pending !== null && !newRunnerJob) {
    const nextPending = { ...pending, attempts: pending.attempts + 1 };
    if (nextPending.attempts <= PENDING_START_MAX_POLLS) {
      return { poll: true, pending: nextPending, timedOut: false };
    }
    return { poll: false, pending: null, timedOut: true };
  }
  return { poll: job.state === "running", pending: null, timedOut: false };
}

async function refreshStatus() {
  const response = await request("/api/maintenance/status");
  if (response.status === 401) {
    stopPolling();
    pendingStart = null;
    dashboard.hidden = true;
    loginPanel.hidden = false;
    csrfToken = null;
    return;
  }
  if (!response.ok) {
    showMessage("Status kann derzeit nicht gelesen werden.");
    stopPolling();
    pendingStart = null;
    return;
  }
  const job = await response.json();
  if (typeof job.job_id === "string") {
    lastObservedJobId = job.job_id;
  }
  showMessage(`Auftrag: ${job.action} – ${job.state}`);
  resultText.textContent = JSON.stringify(job, null, 2);
  const decision = pollingDecision(job, pendingStart);
  pendingStart = decision.pending;
  if (decision.timedOut) {
    showMessage("Der gestartete Wartungsauftrag wurde nicht rechtzeitig im Status sichtbar.");
  }
  stopPolling();
  if (decision.poll) {
    pollTimer = window.setTimeout(refreshStatus, POLL_INTERVAL_MS);
  } else {
    pendingStart = null;
  }
}

async function startAction(action) {
  const response = await request(`/api/maintenance/${action}`, { method: "POST" });
  if (!response.ok) {
    showMessage("Wartungsauftrag konnte nicht gestartet werden.");
    return;
  }
  showMessage("Wartungsauftrag wurde gestartet.");
  stopPolling();
  pendingStart = { baselineJobId: lastObservedJobId, attempts: 0 };
  await refreshStatus();
}

document.querySelector("#login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const password = document.querySelector("#password").value;
  const response = await fetch("/api/session", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
    body: JSON.stringify({ password }),
  });
  document.querySelector("#password").value = "";
  if (!response.ok) {
    showMessage("Anmeldung fehlgeschlagen.");
    return;
  }
  csrfToken = (await response.json()).csrf_token;
  loginPanel.hidden = true;
  dashboard.hidden = false;
  await refreshStatus();
});

document.querySelector("#check-button").addEventListener("click", () => startAction("check"));
document.querySelector("#backup-button").addEventListener("click", () => {
  if (!document.querySelector("#backup-confirmed").checked) {
    showMessage("Bitte das Backup sichtbar bestätigen.");
    return;
  }
  startAction("backup");
});
document.querySelector("#update-button").addEventListener("click", () => {
  if (document.querySelector("#update-confirmation").value !== "UPDATE") {
    showMessage("Bitte UPDATE exakt eingeben.");
    return;
  }
  startAction("update");
});
document.querySelector("#logout-button").addEventListener("click", async () => {
  await request("/api/session/logout", { method: "POST" });
  stopPolling();
  csrfToken = null;
  pendingStart = null;
  dashboard.hidden = true;
  loginPanel.hidden = false;
});
