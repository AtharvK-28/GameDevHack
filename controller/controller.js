// Sends intent to Godot. The host owns identity, role, movement and game rules.
"use strict";

// --- Protocol constants and page elements ---
const STORAGE_PID = "ghostedMoversPid";
const STORAGE_NAME = "ghostedMoversName";
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
let playerId = readStorage(STORAGE_PID);
const heldPointers = new Map();

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
    send({ type: "hello", name: playerName, ...(playerId ? { pid: playerId } : {}) });
  });
  socket.addEventListener("message", event => {
    try { handleMessage(JSON.parse(event.data)); }
    catch (error) { console.warn("Ignored invalid host message", error); }
  });
  socket.addEventListener("close", event => {
    releaseInputs();
    joined = false;
    setControlsEnabled(false);
    elements["ready-button"].disabled = true;
    if (event.code === 1008 || event.reason === "Rejoined from another connection") {
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
      playerId = message.pid;
      playerSlot = message.slot;
      writeStorage(STORAGE_PID, playerId);
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
      break;
    case "lobby":
      renderRoster(message.players);
      break;
    case "role":
      showRole(message);
      break;
    case "hud":
      if (activeRole === "mover") {
        elements["held-label"].textContent = !message.held ? "Hands free" : Number.isFinite(message.value) ? `${message.held} · ₹${message.value.toLocaleString("en-IN")}` : message.held;
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
  elements.lobby.hidden = true;
  elements.controls.hidden = false;
  elements["mover-buttons"].hidden = isGhost;
  elements["ghost-buttons"].hidden = !isGhost;
  elements["player-label"].textContent = `${playerName} · ${isGhost ? "GHOST" : `PLAYER ${playerSlot + 1}`}`;
  elements["held-label"].textContent = "Carry it to the truck. Don't break it.";
  elements["held-label"].hidden = isGhost;
  elements.energy.hidden = !isGhost;
  elements["haunt-label"].textContent = message.arena === "Ghost Ship" ? "WIND" : message.arena === "Abandoned Museum" ? "LIGHTS OUT" : "SHAKE";
  for (const button of ghostButtons) {
    button.classList.remove("unavailable");
    button.style.setProperty("--cooldown", 0);
  }
  setControlsEnabled(true);
}

function renderGhostHud(message) {
  // The host decides what is available (ok) and sends the costs, so no game rule lives here.
  const energy = Number.isFinite(message.energy) ? message.energy : 0;
  const costs = message.costs ?? {};
  const possessing = typeof message.action === "string" && message.action !== "";
  const locked = Number(message.cd?.possess) > 0;
  elements["energy-value"].textContent = Math.floor(energy);
  elements["energy-fill"].style.width = `${Math.max(0, Math.min(1, energy / settings.ghostEnergyMax)) * 100}%`;
  elements["possess-label"].textContent = possessing ? "LEAVE" : "POSSESS";
  elements["possess-note"].textContent = possessing ? "free" : locked ? "exorcised · wait" : "fly into a prop";
  elements["action-label"].textContent = possessing ? message.action : "ACTION";
  elements["action-cost"].textContent = possessing ? costLabel(costs.action) : "possess first";
  elements["haunt1-cost"].textContent = costLabel(costs.haunt1);
  elements["haunt2-cost"].textContent = costLabel(costs.haunt2);
  for (const button of ghostButtons) {
    const name = button.dataset.button;
    button.classList.toggle("unavailable", message.ok?.[name] === false);
    button.style.setProperty("--cooldown", Math.max(0, Math.min(1, Number(message.cd?.[name]) || 0)));
  }
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
    const divisor = Math.max(1, magnitude);
    movement = { x: data.vector.x / divisor, y: -data.vector.y / divisor };
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
  return joined && Boolean(activeRole) && !document.hidden;
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

function readStorage(key) {
  try { return localStorage.getItem(key) || ""; }
  catch { return ""; }
}

function writeStorage(key, value) {
  try { localStorage.setItem(key, value); }
  catch { elements["lobby-note"].textContent = "Keep this page open: this browser cannot save your rejoin ID."; }
}
