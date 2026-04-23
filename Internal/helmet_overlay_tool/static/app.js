const state = {
  offsets: [],
  direction: 0,
  frame: 0,
  cache: 0,
  baseSize: { width: 398, height: 310 },
  helmetSize: { width: 177, height: 138 },
  settings: [],
};

const els = {
  canvas: document.querySelector("#canvas"),
  direction: document.querySelector("#direction"),
  frame: document.querySelector("#frame"),
  offsetX: document.querySelector("#offsetX"),
  offsetY: document.querySelector("#offsetY"),
  opacity: document.querySelector("#opacity"),
  helmetGrow: document.querySelector("#helmetGrow"),
  scope: document.querySelector("#scope"),
  status: document.querySelector("#status"),
  filmstrip: document.querySelector("#filmstrip"),
  regenerate: document.querySelector("#regenerate"),
  reset: document.querySelector("#reset"),
  copyPrevious: document.querySelector("#copyPrevious"),
  driftX: document.querySelector("#driftX"),
  driftY: document.querySelector("#driftY"),
  driftAnchor: document.querySelector("#driftAnchor"),
  applyDrift: document.querySelector("#applyDrift"),
  applyDriftAll: document.querySelector("#applyDriftAll"),
  invertDrift: document.querySelector("#invertDrift"),
};

const ctx = els.canvas.getContext("2d");

function frameIndex(direction = state.direction, frame = state.frame) {
  return direction * 16 + frame;
}

function targetIndices() {
  const indices = [];
  if (els.scope.value === "frame") return [frameIndex()];
  if (els.scope.value === "direction") {
    for (let frame = 0; frame < 16; frame += 1) indices.push(frameIndex(state.direction, frame));
    return indices;
  }
  if (els.scope.value === "animation-frame") {
    for (let direction = 0; direction < 16; direction += 1) indices.push(frameIndex(direction, state.frame));
    return indices;
  }
  for (let index = 0; index < 256; index += 1) indices.push(index);
  return indices;
}

function allFrameIndices() {
  return Array.from({ length: 256 }, (_, index) => index);
}

function image(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });
}

async function draw() {
  const index = frameIndex();
  const version = state.cache;
  const [base, helmet] = await Promise.all([
    image(`/api/frame/base/${index}.png?v=${version}`),
    image(`/api/frame/helmet/${index}.png?v=${version}`),
  ]);
  ctx.clearRect(0, 0, els.canvas.width, els.canvas.height);
  ctx.drawImage(base, 0, 0);
  ctx.globalAlpha = Number(els.opacity.value);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(helmet, 0, 0, state.baseSize.width, state.baseSize.height);
  ctx.globalAlpha = 1;
}

function syncInputs() {
  els.direction.value = state.direction;
  els.frame.value = state.frame;
  const offset = state.offsets[frameIndex()] || { x: 0, y: 0 };
  const settings = state.settings[frameIndex()] || { grow: 0 };
  els.offsetX.value = offset.x;
  els.offsetY.value = offset.y;
  els.helmetGrow.value = settings.grow;
}

function setStatus(text) {
  els.status.textContent = text;
}

async function saveCurrentOffset() {
  const index = frameIndex();
  const payload = {
    index,
    x: Number(els.offsetX.value),
    y: Number(els.offsetY.value),
  };
  const response = await fetch("/api/offset", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const data = await response.json();
  state.offsets = data.offsets;
  state.cache += 1;
  syncInputs();
  renderFilmstrip();
  await draw();
}

async function saveSettings() {
  const indices = targetIndices();
  const response = await fetch("/api/settings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      indices,
      grow: Number(els.helmetGrow.value),
    }),
  });
  const data = await response.json();
  state.settings = data.settings;
  state.cache += 1;
  syncInputs();
  renderFilmstrip();
  const grow = Number(els.helmetGrow.value);
  const target = indices.length === 256 ? "all frames" : "selected target";
  setStatus(`Helmet size set to ${grow >= 0 ? "+" : ""}${grow} px for ${target}.`);
  await draw();
}

async function bulkNudge(dx, dy) {
  const response = await fetch("/api/bulk-offset", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ indices: targetIndices(), dx, dy }),
  });
  const data = await response.json();
  state.offsets = data.offsets;
  state.cache += 1;
  syncInputs();
  renderFilmstrip();
  await draw();
}

async function resetTarget() {
  const response = await fetch("/api/reset", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ indices: targetIndices() }),
  });
  const data = await response.json();
  state.offsets = data.offsets;
  state.cache += 1;
  syncInputs();
  renderFilmstrip();
  await draw();
}

async function applyCumulativeCorrection(invert = false, indices = targetIndices()) {
  const response = await fetch("/api/cumulative-correction", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      indices,
      stepX: Number(els.driftX.value),
      stepY: Number(els.driftY.value),
      anchor: els.driftAnchor.value,
      invert,
    }),
  });
  const data = await response.json();
  state.offsets = data.offsets;
  state.cache += 1;
  syncInputs();
  renderFilmstrip();
  const target = indices.length === 256 ? "whole sheet" : "selected target";
  setStatus(invert ? `Applied inverse cumulative correction to ${target}.` : `Applied cumulative correction to ${target}.`);
  await draw();
}

async function copyPrevious() {
  const index = frameIndex();
  const previous = index === 0 ? 255 : index - 1;
  const offset = state.offsets[previous] || { x: 0, y: 0 };
  els.offsetX.value = offset.x;
  els.offsetY.value = offset.y;
  await saveCurrentOffset();
}

function selectFrame(direction, frame) {
  state.direction = Math.max(0, Math.min(15, direction));
  state.frame = Math.max(0, Math.min(15, frame));
  syncInputs();
  renderFilmstrip();
  draw();
}

function renderFilmstrip() {
  els.filmstrip.replaceChildren();
  for (let frame = 0; frame < 16; frame += 1) {
    const index = frameIndex(state.direction, frame);
    const button = document.createElement("button");
    button.type = "button";
    button.className = `thumb${frame === state.frame ? " active" : ""}`;
    button.addEventListener("click", () => selectFrame(state.direction, frame));

    const img = document.createElement("img");
    img.src = `/api/frame/helmet/${index}.png?v=${state.cache}`;
    const label = document.createElement("span");
    const offset = state.offsets[index] || { x: 0, y: 0 };
    const settings = state.settings[index] || { grow: 0 };
    label.textContent = `${frame} ${offset.x},${offset.y} ${settings.grow >= 0 ? "+" : ""}${settings.grow}px`;
    button.append(img, label);
    els.filmstrip.append(button);
  }
}

function bindEvents() {
  els.direction.addEventListener("change", () => selectFrame(Number(els.direction.value), state.frame));
  els.frame.addEventListener("change", () => selectFrame(state.direction, Number(els.frame.value)));
  els.offsetX.addEventListener("change", saveCurrentOffset);
  els.offsetY.addEventListener("change", saveCurrentOffset);
  els.opacity.addEventListener("input", draw);
  els.helmetGrow.addEventListener("change", saveSettings);
  els.reset.addEventListener("click", resetTarget);
  els.copyPrevious.addEventListener("click", copyPrevious);
  els.applyDrift.addEventListener("click", () => applyCumulativeCorrection(false));
  els.applyDriftAll.addEventListener("click", () => applyCumulativeCorrection(false, allFrameIndices()));
  els.invertDrift.addEventListener("click", () => applyCumulativeCorrection(true));
  document.querySelectorAll(".sizePreset").forEach((button) => {
    button.addEventListener("click", () => {
      els.helmetGrow.value = button.dataset.grow;
      saveSettings();
    });
  });

  document.querySelector("#up").addEventListener("click", () => bulkNudge(0, -1));
  document.querySelector("#down").addEventListener("click", () => bulkNudge(0, 1));
  document.querySelector("#left").addEventListener("click", () => bulkNudge(-1, 0));
  document.querySelector("#right").addEventListener("click", () => bulkNudge(1, 0));

  els.regenerate.addEventListener("click", async () => {
    setStatus("Regenerating spritesheets...");
    const response = await fetch("/api/regenerate", { method: "POST" });
    const data = await response.json();
    state.cache += 1;
    setStatus(`Regenerated ${data.written.length} helmet sheets.`);
    await draw();
  });

  window.addEventListener("keydown", (event) => {
    if (event.target.matches("input, select")) return;
    const step = event.shiftKey ? 5 : 1;
    if (event.key === "ArrowUp") bulkNudge(0, -step);
    if (event.key === "ArrowDown") bulkNudge(0, step);
    if (event.key === "ArrowLeft") bulkNudge(-step, 0);
    if (event.key === "ArrowRight") bulkNudge(step, 0);
    if (event.key === "[") selectFrame(state.direction, state.frame - 1);
    if (event.key === "]") selectFrame(state.direction, state.frame + 1);
  });
}

async function init() {
  const response = await fetch("/api/state");
  const data = await response.json();
  state.offsets = data.offsets;
  state.settings = data.settings || [];
  state.baseSize = data.base;
  state.helmetSize = data.helmet;
  els.canvas.width = data.base.width;
  els.canvas.height = data.base.height;
  bindEvents();
  syncInputs();
  renderFilmstrip();
  await draw();
  setStatus("Use arrow keys to nudge. Hold Shift for 5 px. Offsets save immediately.");
}

init().catch((error) => {
  console.error(error);
  setStatus(`Error: ${error.message}`);
});
