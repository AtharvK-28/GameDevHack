// Sends intent to Godot. The host owns identity, role, movement and game rules.
// Joining needs the host's session key (from the QR link, after "#k=") or its 6-letter join code; the host then
// gives this phone a pid and a secret, kept for this session only, so only this phone can rejoin its slot.
"use strict";

// --- Protocol constants and page elements ---
const STORAGE_IDENTITY = "ghostedMoversIdentity";
const STORAGE_NAME = "ghostedMoversName";
const CLOSE_NEW_LOBBY = 4002;
const CLOSE_DENIED = 4003;
const FIRST_APP_CLOSE_CODE = 4000; // The host's own refusals: show the reason and don't retry.
const MILLISECONDS_PER_SECOND = 1000;
const elements = Object.fromEntries(Array.from(document.querySelectorAll("[id]"), element => [element.id, element]));
const actionButtons = Array.from(document.querySelectorAll("[data-button]"));
const ghostButtons = Array.from(document.querySelectorAll("#ghost-buttons [data-button]"));

// --- Connection and input state ---
let settings;
let socket;
let reconnectTimer;
let joystick;
let wakeLock;
let joined = false;
let activeRole = "";
let movement = { x: 0, y: 0 };
let playerSlot = 0;
let playerName = "";
let sessionKey = new URLSearchParams(location.hash.slice(1)).get("k") || "";
let identity = readIdentity(); // { key, pid, secret } from the last welcome in this session.
let matchPhase = null; // Null outside a match: the greybox harness shows controls as soon as a role arrives.
let matchState = {};
const heldPointers = new Map();
const SCREENS = ["lobby", "controls", "reveal", "result", "final"];
const LIVE_PHASES = ["live", "paused"];

// --- Setup ---
initialize().catch(error => {
  elements.connection.textContent = "Controller could not load";
  elements["lobby-note"].textContent = error.message;
  elements["join-button"].disabled = true;
});

async function initialize() {
  elements["join-button"].disabled = true;
  const response = await fetch("settings.json", { cache: "no-store" });
  if (!response.ok) throw new Error("Controller settings are missing. Ask the host to restart setup.");
  settings = await response.json();
  if (!window.nipplejs) throw new Error("The joystick library is missing from the host.");
  elements["player-name"].maxLength = settings.maxNameLength;
  elements["player-name"].value = readStorage(STORAGE_NAME);
  if (!sessionKey) sessionKey = identity.key || "";
  if (identity.key !== sessionKey) identity = {};
  elements["code-field"].hidden = Boolean(sessionKey);
  elements["join-button"].disabled = false;
  setupJoystick();
  setupButtons();
  setupPageEvents();
  setInterval(sendMovement, MILLISECONDS_PER_SECOND / settings.inputRate);
}

function setupPageEvents() {
  elements["join-form"].addEventListener("submit", event => {
    event.preventDefault();
    playerName = elements["player-name"].value.trim();
    if (!playerName) return;
    if (!sessionKey && elements["join-code"].value.trim().length !== settings.joinCodeLength) {
      elements["lobby-note"].textContent = `Type the ${settings.joinCodeLength}-letter code from the big screen.`;
      return;
    }
    writeStorage(STORAGE_NAME, playerName);
    requestDisplay();
    connect();
  });
  elements["ready-button"].addEventListener("click", () => {
    send({ type: "ready" });
    elements["ready-button"].disabled = true;
    elements["ready-button"].textContent = "READY — WAITING FOR HOST";
    requestDisplay();
  });
  elements["fullscreen-button"].addEventListener("click", requestDisplay);
  document.addEventListener("visibilitychange", () => {
    releaseInputs();
    if (!document.hidden) requestWakeLock();
  });
  window.addEventListener("blur", releaseInputs);
  window.addEventListener("pagehide", releaseInputs);
  window.addEventListener("resize", releaseInputs);
  window.addEventListener("contextmenu", event => event.preventDefault());
}

// --- WebSocket connection ---
function connect() {
  clearTimeout(reconnectTimer);
  if (socket && socket.readyState < WebSocket.CLOSING) return;
  elements.connection.textContent = "Connecting…";
  elements["join-button"].disabled = true;
  const hostname = location.hostname.includes(":") ? `[${location.hostname}]` : location.hostname;
  socket = new WebSocket(`ws://${hostname}:${settings.socketPort}`);
  socket.addEventListener("open", () => {
    const credentials = sessionKey ? { key: sessionKey } : { code: elements["join-code"].value.trim().toUpperCase() };
    const rejoin = identity.pid ? { pid: identity.pid, secret: identity.secret } : {};
    send({ type: "hello", name: playerName, ...credentials, ...rejoin });
  });
  socket.addEventListener("message", event => {
    try { handleMessage(JSON.parse(event.data)); }
    catch (error) { console.warn("Ignored invalid host message", error); }
  });
  socket.addEventListener("close", event => {
    releaseInputs();
    joined = false;
    activeRole = "";
    matchPhase = null;
    matchState = {};
    elements["join-form"].hidden = false;
    elements.joined.hidden = true;
    render();
    setControlsEnabled(false);
    elements["ready-button"].disabled = true;
    if (event.code >= FIRST_APP_CLOSE_CODE || event.code === 1008 || event.reason === "Rejoined from another connection") {
      if (event.code === CLOSE_NEW_LOBBY || event.code === CLOSE_DENIED) forgetSession();
      elements.connection.textContent = event.reason || "Join declined";
      elements["lobby-note"].textContent = event.reason;
      elements["join-button"].disabled = false;
      return;
    }
    elements.connection.textContent = "Connection lost · retrying…";
    reconnectTimer = setTimeout(connect, settings.reconnectDelayMs);
  });
  socket.addEventListener("error", () => {
    elements.connection.textContent = "Host unavailable · check Wi-Fi and that the game is running";
  });
}

function handleMessage(message) {
  switch (message.type) {
    case "welcome":
      releaseInputs();
      joined = true;
      activeRole = "";
      sessionKey = message.key;
      identity = { key: message.key, pid: message.pid, secret: message.secret };
      writeStorage(STORAGE_IDENTITY, JSON.stringify(identity));
      playerSlot = message.slot;
      document.documentElement.style.setProperty("--player", message.colour);
      elements.connection.textContent = `Connected · Player ${playerSlot + 1}`;
      elements["join-form"].hidden = true;
      elements.joined.hidden = false;
      elements.lobby.hidden = false;
      elements.controls.hidden = true;
      elements.identity.textContent = `${playerName} · Player ${playerSlot + 1}`;
      elements["ready-button"].disabled = false;
      elements["ready-button"].textContent = "READY TO MOVE";
      sendMovement();
      render();
      break;
    case "lobby":
      renderRoster(message.players);
      break;
    case "role":
      showRole(message);
      render();
      break;
    case "match":
      matchState = message;
      matchPhase = message.phase;
      render();
      break;
    case "hud":
      if (activeRole === "mover") {
        renderMoverHud(message);
      } else if (activeRole === "ghost") {
        renderGhostHud(message);
      }
      break;
    case "buzz":
      if (navigator.vibrate && Number.isFinite(message.ms)) navigator.vibrate(message.ms);
      break;
  }
}

function showRole(message) {
  releaseInputs();
  activeRole = message.role;
  const isGhost = activeRole === "ghost";
  document.body.classList.toggle("ghost", isGhost);
  elements["mover-buttons"].hidden = isGhost;
  elements["ghost-buttons"].hidden = !isGhost;
  elements["player-label"].textContent = `${playerName} · ${isGhost ? "GHOST" : `PLAYER ${playerSlot + 1}`}`;
  elements["held-label"].textContent = "Carry it to the truck. Don't break it.";
  elements["held-label"].hidden = isGhost;
  elements.energy.hidden = !isGhost;
  elements["haunt-label"].textContent = message.arena === "Ghost Ship" ? "WIND" : message.arena === "Abandoned Museum" ? "LIGHTS OUT" : "SHAKE";
  elements["curse-note"].hidden = true;
  for (const button of ghostButtons) {
    button.classList.remove("unavailable");
    button.style.setProperty("--cooldown", 0);
  }
}

// --- Match screens: the host's phase decides what the phone shows ---
function render() {
  const inMatch = matchPhase !== null;
  let screen = "lobby";
  if (joined && !inMatch) screen = activeRole ? "controls" : "lobby";
  else if (joined && ["setup", "reveal"].includes(matchPhase)) screen = "reveal";
  else if (joined && LIVE_PHASES.includes(matchPhase)) screen = activeRole ? "controls" : "lobby";
  else if (joined && matchPhase === "result") screen = "result";
  else if (joined && matchPhase === "final") screen = "final";
  for (const name of SCREENS) elements[name].hidden = name !== screen;

  // Controls work only in live play; anything held is let go the moment play stops.
  const playable = canPlay();
  if (!playable && heldPointers.size > 0) releaseInputs();
  setControlsEnabled(playable);
  elements["pause-notice"].hidden = matchPhase !== "paused";
  elements["pause-reason"].textContent = matchState.pauseReason || "";
  elements.timer.hidden = !LIVE_PHASES.includes(matchPhase);
  elements.timer.textContent = clock(matchState.t);
  if (screen === "lobby" && inMatch) renderReady();
  if (screen === "reveal") renderReveal();
  if (screen === "result") renderResult();
  if (screen === "final") renderFinal();
}

function renderReady() {
  const me = (matchState.players || []).find(player => player.slot === playerSlot);
  const ready = Boolean(me?.ready);
  elements["ready-button"].disabled = ready;
  elements["ready-button"].textContent = ready ? "READY — WAITING FOR HOST" : "READY TO MOVE";
}

function renderReveal() {
  const isGhost = activeRole === "ghost";
  elements["reveal-round"].textContent = `ROUND ${matchState.round} OF ${matchState.rounds}`;
  elements["reveal-role"].textContent = isGhost ? "YOU ARE THE GHOST" : "YOU'RE A MOVER";
  elements["reveal-line"].textContent = isGhost ? "Break everything." : "Carry it to the truck. Don't break it.";
  elements["reveal-countdown"].textContent = matchState.countdown > 0 ? matchState.countdown : "";
  document.body.classList.toggle("ghost", isGhost);
}

function renderResult() {
  const result = matchState.result || {};
  const won = activeRole === "ghost" ? !result.moversWon : Boolean(result.moversWon);
  const me = (matchState.standings || []).find(row => row.slot === playerSlot);
  elements["result-round"].textContent = `ROUND ${matchState.round} OF ${matchState.rounds} · ${result.moversWon ? "MOVERS WIN" : "THE GHOST WINS"}`;
  elements["result-title"].textContent = won ? "YOU WIN" : "YOU LOSE";
  elements["result-reason"].textContent = result.reason || "";
  elements["result-points"].textContent = me ? `+${Math.round(me.roundPoints)} this round · ${Math.round(me.points)} total` : "";
}

function renderFinal() {
  const rows = matchState.standings || [];
  elements["final-title"].textContent = rows.length ? `${rows[0].name} wins` : "";
  elements["final-standings"].replaceChildren(...rows.map(row => {
    const item = document.createElement("li");
    item.textContent = `${row.name} · ${Math.round(row.points)} points`;
    if (row.slot === playerSlot) item.classList.add("me");
    return item;
  }));
}

function clock(seconds) {
  const whole = Math.max(0, Math.ceil(Number(seconds) || 0));
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}

function renderMoverHud(message) {
  elements["held-label"].textContent = !message.held ? "Hands free" : Number.isFinite(message.value) ? `${message.held} · ₹${message.value.toLocaleString("en-IN")}` : message.held;
  const generator = message.generator;
  if (generator?.total && (!message.held || message.held === "Generator Battery")) {
    elements["held-label"].textContent += generator.powered ? " · Generator ON" : ` · Generator ${generator.delivered}/${generator.total}`;
  }
  // A cursed item stays heavy for its remaining seconds, even after being dropped and picked up again.
  const cursed = Number(message.cursed) || 0;
  elements["curse-note"].hidden = cursed <= 0;
  elements["curse-note"].textContent = `CURSED · HEAVY ${cursed}s`;
}

function renderGhostHud(message) {
  // The host decides what is available (ok) and sends the costs, so no game rule lives here.
  const energy = Number.isFinite(message.energy) ? message.energy : 0;
  const costs = message.costs ?? {};
  const possessing = typeof message.action === "string" && message.action !== "";
  const locked = Number(message.cd?.possess) > 0;
  elements["energy-value"].textContent = Math.floor(energy);
  elements["energy-fill"].style.width = `${Math.max(0, Math.min(1, energy / settings.ghostEnergyMax)) * 100}%`;
  const reasons = message.reasons ?? {};
  const simple = Boolean(message.simple);
  elements["possess-label"].textContent = possessing ? "LEAVE" : "POSSESS";
  elements["possess-note"].textContent = reasons.possess ?? (possessing ? "free" : locked ? "exorcised · wait" : "fly into a prop");
  elements["action-label"].textContent = possessing ? message.action : "ACTION";
  elements["action-cost"].textContent = noteFor("action", message, possessing ? costLabel(costs.action) : "possess first");
  elements["haunt1-cost"].textContent = noteFor("haunt1", message, costLabel(costs.haunt1));
  elements["haunt2-cost"].textContent = costLabel(costs.haunt2);
  elements["haunt3-cost"].textContent = noteFor("haunt3", message, costLabel(costs.haunt3));
  // The demo ghost has Curse instead of Slime.
  elements["haunt2-button"].hidden = simple;
  elements["haunt3-button"].hidden = !simple;
  elements["ghost-status"].hidden = !simple;
  elements["ghost-status"].textContent = statusLine(message);
  for (const button of ghostButtons) {
    const name = button.dataset.button;
    button.classList.toggle("unavailable", message.ok?.[name] === false);
    button.style.setProperty("--cooldown", Math.max(0, Math.min(1, Number(message.cd?.[name]) || 0)));
  }
}

function noteFor(name, message, readyText) {
  // Unavailable: the host's reason with its seconds, e.g. "Haunting lock: 2s". Available: the cost.
  return message.ok?.[name] === false && message.reasons?.[name] ? message.reasons[name] : readyText;
}

function statusLine(message) {
  const seconds = message.seconds ?? {};
  if (message.generatorPowered) return "Generator ON: slower flight/regen, longer cooldowns";
  if (seconds.opening > 0) return `Hauntings unlock in ${seconds.opening}s`;
  if (seconds.shared > 0) return `Next haunting in ${seconds.shared}s`;
  return message.target ? `Curse target: ${message.target}` : "Fly near loot to curse it";
}

function costLabel(cost) {
  return Number.isFinite(cost) ? `${cost} energy` : "";
}

function renderRoster(players) {
  elements.roster.replaceChildren();
  for (const player of players) {
    const row = document.createElement("li");
    const name = document.createElement("span");
    const state = document.createElement("strong");
    name.textContent = player.name;
    state.textContent = player.ready ? "READY" : "JOINED";
    row.append(name, state);
    elements.roster.append(row);
  }
}

// --- Continuous joystick and button edges ---
function setupJoystick() {
  joystick = nipplejs.create({ zone: elements["joystick-zone"], mode: "dynamic", color: "#183a38", size: settings.joystickSize, multitouch: false });
  joystick.on("start", () => elements["joystick-zone"].classList.add("active"));
  joystick.on("move", (_event, data) => {
    if (!canPlay()) return;
    const magnitude = Math.hypot(data.vector.x, data.vector.y);
    if (magnitude < settings.joystickDeadzone) {
      movement = { x: 0, y: 0 };
      return;
    }
    // Rescale past the dead zone so speed starts from zero instead of jumping; the host adds the response curve.
    const scaled = Math.min(1, (magnitude - settings.joystickDeadzone) / (1 - settings.joystickDeadzone));
    movement = { x: (data.vector.x / magnitude) * scaled, y: (-data.vector.y / magnitude) * scaled };
  });
  joystick.on("end", () => {
    elements["joystick-zone"].classList.remove("active");
    movement = { x: 0, y: 0 };
    sendMovement();
  });
  elements["joystick-zone"].addEventListener("pointercancel", releaseInputs);
}

function setupButtons() {
  for (const button of actionButtons) {
    button.setAttribute("aria-pressed", "false");
    button.addEventListener("pointerdown", event => {
      if (!canPlay() || button.disabled || heldPointers.has(button)) return;
      event.preventDefault();
      button.setPointerCapture(event.pointerId);
      heldPointers.set(button, event.pointerId);
      button.classList.add("pressed");
      button.setAttribute("aria-pressed", "true");
      send({ type: "btn", b: button.dataset.button, down: true });
    });
    for (const eventName of ["pointerup", "pointercancel", "lostpointercapture"]) {
      button.addEventListener(eventName, event => {
        if (heldPointers.get(button) === event.pointerId) releaseButton(button);
      });
    }
    button.addEventListener("keydown", event => {
      if (![" ", "Enter"].includes(event.key) || event.repeat || !canPlay()) return;
      event.preventDefault();
      heldPointers.set(button, "keyboard");
      button.classList.add("pressed");
      button.setAttribute("aria-pressed", "true");
      send({ type: "btn", b: button.dataset.button, down: true });
    });
    button.addEventListener("keyup", event => {
      if ([" ", "Enter"].includes(event.key)) releaseButton(button);
    });
    button.addEventListener("blur", () => {
      if (heldPointers.get(button) === "keyboard") releaseButton(button);
    });
  }
  setControlsEnabled(false);
}

function releaseButton(button) {
  if (!heldPointers.has(button)) return;
  heldPointers.delete(button);
  button.classList.remove("pressed");
  button.setAttribute("aria-pressed", "false");
  send({ type: "btn", b: button.dataset.button, down: false });
}

function releaseInputs() {
  movement = { x: 0, y: 0 };
  elements["joystick-zone"].classList.remove("active");
  for (const button of Array.from(heldPointers.keys())) releaseButton(button);
  sendMovement();
}

function sendMovement() {
  if (!joined || document.hidden) return;
  send({ type: "in", x: movement.x, y: movement.y });
}

function canPlay() {
  const live = matchPhase === null || matchPhase === "live";
  return joined && Boolean(activeRole) && live && !document.hidden;
}

function setControlsEnabled(enabled) {
  for (const button of actionButtons) button.disabled = !enabled;
}

function send(message) {
  if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
}

// --- Optional browser features and storage ---
async function requestDisplay() {
  try {
    if (!document.fullscreenElement && document.documentElement.requestFullscreen) {
      await document.documentElement.requestFullscreen();
    }
    if (screen.orientation?.lock) await screen.orientation.lock("landscape");
  } catch { /* Landscape guidance remains visible when the browser declines. */ }
  requestWakeLock();
}

async function requestWakeLock() {
  if (wakeLock && !wakeLock.released) return;
  try {
    if (!navigator.wakeLock) throw new Error("Wake Lock unavailable");
    wakeLock = await navigator.wakeLock.request("screen");
    elements["control-note"].textContent = "Screen awake · eyes on the big screen.";
  } catch {
    elements["control-note"].textContent = "Set a longer screen timeout to keep playing.";
  }
}

function readIdentity() {
  try {
    const saved = JSON.parse(readStorage(STORAGE_IDENTITY) || "{}");
    return saved && [saved.key, saved.pid, saved.secret].every(value => typeof value === "string") ? saved : {};
  }
  catch { return {}; }
}

function forgetSession() {
  // The key no longer works (a new lobby, or a wrong code): ask for the code on screen.
  sessionKey = "";
  identity = {};
  writeStorage(STORAGE_IDENTITY, "{}");
  history.replaceState(null, "", location.pathname + location.search);
  elements["code-field"].hidden = false;
}

function readStorage(key) {
  try { return localStorage.getItem(key) || ""; }
  catch { return ""; }
}

function writeStorage(key, value) {
  try { localStorage.setItem(key, value); }
  catch { elements["lobby-note"].textContent = "Keep this page open: this browser cannot save your rejoin ID."; }
}
