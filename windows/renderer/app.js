// Checkup renderer. Everything here uses browser APIs so it behaves the
// same on Windows and, during development, anywhere else Electron runs.

const CHECKS = [
  { id: 'overview', title: 'Overview' },
  { id: 'display', title: 'Display & pixels' },
  { id: 'speakers', title: 'Speakers' },
  { id: 'microphone', title: 'Microphone' },
  { id: 'camera', title: 'Camera' },
  { id: 'keyboard', title: 'Keyboard' },
  { id: 'pointer', title: 'Mouse & pointer' },
  { id: 'battery', title: 'Battery & power' },
  { id: 'drives', title: 'Drives & storage' },
  { id: 'network', title: 'Network' },
];

const COLORS = [
  ['Red', '#ff0000'], ['Green', '#00ff00'], ['Blue', '#0000ff'],
  ['Cyan', '#00ffff'], ['Magenta', '#ff00ff'], ['Yellow', '#ffff00'],
  ['White', '#ffffff'], ['50% Grey', '#808080'], ['Black', '#000000'],
];

const $ = (id) => document.getElementById(id);

// The preload bridge from main.js. When the renderer is opened in a plain
// browser - which is how most of it gets developed and checked - the OS-facing
// calls report themselves unavailable instead of taking the whole page down.
const unavailable = (what) => async () => ({ ok: false, error: what + ' needs the desktop app.' });
const bridge = window.checkup || {
  systemInfo: async () => ({
    platform: 'browser', platformName: 'Browser', release: 'n/a', arch: 'n/a',
    hostname: location.host || 'local',
    cpu: (navigator.hardwareConcurrency || 0) + ' logical cores',
    cores: navigator.hardwareConcurrency || 0,
    memoryBytes: navigator.deviceMemory ? navigator.deviceMemory * 1e9 : null,
    isWindows: false,
  }),
  storageBenchmark: unavailable('The disk speed test'),
  battery: unavailable('The battery reading'),
  drives: unavailable('Drive enumeration'),
  network: async () => [],
};

let results = {};
try { results = JSON.parse(localStorage.getItem('checkup.results') || '{}'); } catch { results = {}; }

const statusOf = (id) => (results[id] && results[id].status) || 'Untested';
const noteOf = (id) => (results[id] && results[id].note) || '';
const save = () => localStorage.setItem('checkup.results', JSON.stringify(results));

let current = 'overview';
let guided = { active: false, index: 0 };
const guidedOrder = CHECKS.filter((c) => c.id !== 'overview');

// ---------------------------------------------------------------- navigation

function renderNav() {
  const nav = $('nav');
  nav.innerHTML = '';
  for (const check of CHECKS) {
    const status = statusOf(check.id);
    const button = document.createElement('button');
    button.className = check.id === current ? 'active' : '';
    const symbol = { Pass: '\u2713', Fail: '\u2717', 'N/A': '\u2013', Untested: '\u00b7' }[status];
    button.innerHTML = '<span>' + check.title + '</span><span class="dot dot-' +
      status.toLowerCase().replace('/', '') + '">' + symbol + '</span>';
    button.addEventListener('click', () => select(check.id));
    nav.appendChild(button);
  }
}

function select(id) {
  current = id;
  const position = guidedOrder.findIndex((c) => c.id === id);
  if (guided.active && position >= 0) guided.index = position;
  renderNav();
  renderPanel();
  renderOutcome();
  renderBanner();
}

function renderOutcome() {
  const hasResult = current !== 'overview';
  $('outcome').style.visibility = hasResult ? 'visible' : 'hidden';
  if (!hasResult) return;
  $('result').value = statusOf(current);
  $('notes').value = noteOf(current);
}

// ------------------------------------------------------------------- helpers

function fmtBytes(n) {
  if (n === null || n === undefined) return 'unknown';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let value = n, i = 0;
  while (value >= 1000 && i < units.length - 1) { value /= 1000; i += 1; }
  return value.toFixed(i === 0 ? 0 : 1) + ' ' + units[i];
}

function card(title, body) {
  return '<div class="card"><h2>' + title + '</h2>' + body + '</div>';
}

function bullet(text) {
  return '<p>&bull; ' + text + '</p>';
}

// ------------------------------------------------------------------- panels

function renderPanel() {
  const panel = $('panel');
  teardown();
  const builder = builders[current];
  panel.innerHTML = builder ? builder() : '';
  if (wire[current]) wire[current]();
}

function teardown() {
  stopAudio();
  stopMeter();
  stopCamera();
  exitPixel();
  releaseNotes();
}

const builders = {};
const wire = {};

// Overview ---------------------------------------------------------------

builders.overview = () => {
  const rows = Object.entries(results).length;
  const tally = { Pass: 0, Fail: 0, Untested: 0, 'N/A': 0 };
  for (const check of guidedOrder) tally[statusOf(check.id)] += 1;

  let head = '<div class="kv">';
  head += '<div class="k">Platform</div><div id="sys-platform">reading\u2026</div>';
  head += '<div class="k">Version</div><div id="sys-release">\u2026</div>';
  head += '<div class="k">Architecture</div><div id="sys-arch">\u2026</div>';
  head += '<div class="k">CPU</div><div id="sys-cpu">\u2026</div>';
  head += '<div class="k">Memory</div><div id="sys-mem">\u2026</div>';
  head += '<div class="k">Machine</div><div id="sys-host">\u2026</div>';
  head += '</div>';

  let list = '<div class="kv">';
  for (const check of guidedOrder) {
    list += '<div class="k">' + check.title + '</div><div class="' +
      (statusOf(check.id) === 'Fail' ? 'bad' : statusOf(check.id) === 'Pass' ? 'good' : '') +
      '">' + statusOf(check.id) + '</div>';
  }
  list += '</div>';

  const summary = tally.Fail > 0 ? tally.Fail + ' check(s) failed'
    : tally.Untested === 0 ? 'All checks passed'
    : tally.Pass + ' passed, ' + tally.Untested + ' untested';

  return card('This machine', head) +
    card('Checklist \u2014 ' + summary, list +
      '<p class="hint">' + rows + ' result(s) recorded. Results are saved automatically.</p>') +
    card('Report', '<div class="row">' +
      '<button id="copy-report" class="primary">Copy report</button>' +
      '<button id="reset-checks">Reset checklist</button>' +
      '<span id="copy-state" class="hint"></span></div>');
};

wire.overview = () => {
  bridge.systemInfo().then((info) => {
    $('sys-platform').textContent = info.platformName;
    $('sys-release').textContent = info.release;
    $('sys-arch').textContent = info.arch;
    $('sys-cpu').textContent = info.cpu + ' (' + info.cores + ' cores)';
    $('sys-mem').textContent = fmtBytes(info.memoryBytes);
    $('sys-host').textContent = info.hostname;
  });
  $('copy-report').addEventListener('click', () => {
    navigator.clipboard.writeText(reportText()).then(() => {
      $('copy-state').textContent = 'Copied.';
    });
  });
  $('reset-checks').addEventListener('click', () => {
    results = {};
    save();
    select('overview');
  });
};

// Display ----------------------------------------------------------------

builders.display = () => card('Dead and stuck pixels',
  '<p>A full-screen fill cycles through each colour. Click or press any key to ' +
  'advance; press Escape to stop.</p>' +
  '<div class="row"><button id="start-pixel" class="primary">Start pixel test</button></div>' +
  '<p class="hint">Colours: ' + COLORS.map((c) => c[0]).join(' \u2192 ') + '</p>') +
  card('What to look for',
    bullet('A pixel stuck on the wrong colour against a flat fill is dead or stuck.') +
    bullet('On the black frame, look for backlight bleed in the corners in a dark room.') +
    bullet('On the 50% grey frame, look for faint banding.'));

wire.display = () => {
  $('start-pixel').addEventListener('click', () => enterPixel());
};

let pixelIndex = 0;

function enterPixel() {
  pixelIndex = 0;
  const layer = $('pixel');
  layer.hidden = false;
  if (layer.requestFullscreen) layer.requestFullscreen().catch(() => {});
  paintPixel();
  window.addEventListener('keydown', pixelKey);
  layer.addEventListener('click', nextPixel);
}

function paintPixel() {
  const [name, hex] = COLORS[pixelIndex];
  $('pixel').style.background = hex;
  $('pixel-name').textContent = name + '  \u2022  ' + (pixelIndex + 1) + ' / ' + COLORS.length;
}

function nextPixel() {
  pixelIndex = (pixelIndex + 1) % COLORS.length;
  paintPixel();
}

function pixelKey(event) {
  if (event.key === 'Escape') { exitPixel(); return; }
  event.preventDefault();
  nextPixel();
}

function exitPixel() {
  const layer = $('pixel');
  if (!layer || layer.hidden) return;
  layer.hidden = true;
  window.removeEventListener('keydown', pixelKey);
  layer.removeEventListener('click', nextPixel);
  if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
}

// Speakers ---------------------------------------------------------------

let audioContext = null;
let audioNodes = [];

function stopAudio() {
  for (const node of audioNodes) { try { node.stop(); } catch { /* already stopped */ } }
  audioNodes = [];
}

function ensureAudio() {
  if (!audioContext) audioContext = new AudioContext();
  if (audioContext.state === 'suspended') audioContext.resume();
  return audioContext;
}

function panValue(channel) {
  return channel === 'left' ? -1 : channel === 'right' ? 1 : 0;
}

function playOscillator(frequency, channel, seconds, sweepTo) {
  const ctx = ensureAudio();
  stopAudio();
  const osc = ctx.createOscillator();
  osc.type = 'sine';
  const gain = ctx.createGain();
  const panner = ctx.createStereoPanner();
  panner.pan.value = panValue(channel);

  const now = ctx.currentTime;
  const end = now + seconds;
  osc.frequency.setValueAtTime(frequency, now);
  if (sweepTo) osc.frequency.exponentialRampToValueAtTime(sweepTo, end);
  // Fade the edges so the tone does not click.
  gain.gain.setValueAtTime(0, now);
  gain.gain.linearRampToValueAtTime(0.28, now + 0.02);
  gain.gain.setValueAtTime(0.28, end - 0.05);
  gain.gain.linearRampToValueAtTime(0, end);

  osc.connect(gain).connect(panner).connect(ctx.destination);
  osc.start(now);
  osc.stop(end);
  audioNodes = [osc];
}

function playNoise(channel) {
  const ctx = ensureAudio();
  stopAudio();
  const seconds = 1.5;
  const buffer = ctx.createBuffer(1, ctx.sampleRate * seconds, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < data.length; i += 1) data[i] = (Math.random() * 2 - 1) * 0.25;
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  const panner = ctx.createStereoPanner();
  panner.pan.value = panValue(channel);
  source.connect(panner).connect(ctx.destination);
  source.start();
  audioNodes = [source];
}

let speakerChannel = 'both';

builders.speakers = () => card('Channel isolation',
  '<p>Turn the volume down first. Play a tone on each side: it should come only ' +
  'from that speaker.</p>' +
  '<div class="row"><span class="hint">Channel</span>' +
  '<select id="speaker-channel"><option>both</option><option>left</option><option>right</option></select>' +
  '<button id="tone-440" class="primary">440 Hz</button>' +
  '<button id="tone-1k">1 kHz</button>' +
  '<button id="stop-tone">Stop</button></div>') +
  card('Full range',
    '<div class="row"><button id="sweep">Sweep 20 Hz \u2192 20 kHz</button>' +
    '<button id="noise">White noise</button></div>') +
  card('What to listen for',
    bullet('Rattling on the sweep usually means a loose speaker or a resonance in the case.') +
    bullet('The two sides should sound equally loud on the same tone.') +
    bullet('White noise should sound steady, without dropouts.'));

wire.speakers = () => {
  $('speaker-channel').value = speakerChannel;
  $('speaker-channel').addEventListener('change', (e) => { speakerChannel = e.target.value; });
  $('tone-440').addEventListener('click', () => playOscillator(440, speakerChannel, 2.5));
  $('tone-1k').addEventListener('click', () => playOscillator(1000, speakerChannel, 2.5));
  $('sweep').addEventListener('click', () => playOscillator(20, speakerChannel, 5, 20000));
  $('noise').addEventListener('click', () => playNoise(speakerChannel));
  $('stop-tone').addEventListener('click', () => stopAudio());
};

// Microphone -------------------------------------------------------------

let micStream = null;
let micAnalyser = null;
let meterFrame = null;
let recorder = null;
let recordedChunks = [];
let recordedUrl = null;

function stopMeter() {
  if (meterFrame) cancelAnimationFrame(meterFrame);
  meterFrame = null;
  if (micStream) { micStream.getTracks().forEach((t) => t.stop()); micStream = null; }
  micAnalyser = null;
}

builders.microphone = () => card('Record and play back',
  '<p>Record a few seconds, then play it back. The meter should respond to your ' +
  'voice and fall silent when you stop.</p>' +
  '<div class="row">' +
  '<button id="mic-start" class="primary">Start recording</button>' +
  '<button id="mic-stop" disabled>Stop recording</button>' +
  '<button id="mic-play" disabled>Play back</button></div>' +
  '<p><span class="hint">Input level</span></p>' +
  '<div class="bar" id="mic-bar"><i style="width:0%"></i></div>' +
  '<p class="hint" id="mic-state">Idle.</p>' +
  '<audio id="mic-audio" controls hidden></audio>') +
  card('What to listen for',
    bullet('Your voice should be clear, not crackly or muffled.') +
    bullet('Hiss that grows louder over time points at a failing input.'));

wire.microphone = () => {
  $('mic-start').addEventListener('click', startRecording);
  $('mic-stop').addEventListener('click', () => recorder && recorder.stop());
  $('mic-play').addEventListener('click', () => {
    const audio = $('mic-audio');
    if (recordedUrl) { audio.src = recordedUrl; audio.hidden = false; audio.play(); }
  });
};

async function startRecording() {
  try {
    micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch (error) {
    $('mic-state').textContent = 'Microphone unavailable: ' + error.message;
    return;
  }
  const ctx = ensureAudio();
  const source = ctx.createMediaStreamSource(micStream);
  micAnalyser = ctx.createAnalyser();
  micAnalyser.fftSize = 1024;
  source.connect(micAnalyser);

  const data = new Uint8Array(micAnalyser.fftSize);
  const tick = () => {
    if (!micAnalyser) return;
    micAnalyser.getByteTimeDomainData(data);
    let peak = 0;
    for (let i = 0; i < data.length; i += 1) peak = Math.max(peak, Math.abs(data[i] - 128) / 128);
    const percent = Math.min(100, peak * 100);
    const bar = $('mic-bar');
    bar.className = 'bar' + (percent > 90 ? ' clip' : percent > 70 ? ' hot' : '');
    bar.firstElementChild.style.width = percent.toFixed(1) + '%';
    meterFrame = requestAnimationFrame(tick);
  };
  tick();

  recordedChunks = [];
  recorder = new MediaRecorder(micStream);
  recorder.ondataavailable = (event) => { if (event.data.size) recordedChunks.push(event.data); };
  recorder.onstop = () => {
    const blob = new Blob(recordedChunks, { type: recorder.mimeType });
    recordedUrl = URL.createObjectURL(blob);
    $('mic-play').disabled = false;
    $('mic-state').textContent = 'Recorded. Play it back.';
    $('mic-stop').disabled = true;
    $('mic-start').disabled = false;
    stopMeter();
  };
  recorder.start();
  $('mic-state').textContent = 'Recording \u2014 say something.';
  $('mic-start').disabled = true;
  $('mic-stop').disabled = false;
}

// Camera -----------------------------------------------------------------

let cameraStream = null;

function stopCamera() {
  if (cameraStream) {
    cameraStream.getTracks().forEach((t) => t.stop());
    cameraStream = null;
  }
}

builders.camera = () => card('Live preview',
  '<div class="row"><button id="cam-start" class="primary">Start camera</button>' +
  '<button id="cam-stop">Stop</button><button id="cam-list">List devices</button></div>' +
  '<p><video id="cam-video" width="560" height="315" autoplay playsinline muted></video></p>' +
  '<p class="hint" id="cam-state">Idle.</p>' +
  '<div class="kv" id="cam-devices"></div>') +
  card('What to look for',
    bullet('The image should be sharp and evenly lit, with no frozen frame.') +
    bullet('Cover the lens: the picture should go black.'));

wire.camera = () => {
  $('cam-start').addEventListener('click', startCamera);
  $('cam-stop').addEventListener('click', () => { stopCamera(); $('cam-state').textContent = 'Stopped.'; });
  $('cam-list').addEventListener('click', listCameras);
};

async function startCamera() {
  try {
    cameraStream = await navigator.mediaDevices.getUserMedia({ video: true });
    $('cam-video').srcObject = cameraStream;
    const track = cameraStream.getVideoTracks()[0];
    const settings = track.getSettings();
    $('cam-state').textContent = 'Showing ' + track.label +
      (settings.width ? ' at ' + settings.width + ' x ' + settings.height : '');
  } catch (error) {
    $('cam-state').textContent = 'Camera unavailable: ' + error.message;
  }
}

async function listCameras() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const cameras = devices.filter((d) => d.kind === 'videoinput');
  $('cam-devices').innerHTML = cameras.length
    ? cameras.map((c) => '<div class="k">Camera</div><div>' + (c.label || 'unnamed') + '</div>').join('')
    : '<div class="k">Cameras</div><div>none reported</div>';
}

// Keyboard ---------------------------------------------------------------

const KEY_ROWS = [
  ['Backquote', 'Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5', 'Digit6', 'Digit7', 'Digit8', 'Digit9', 'Digit0', 'Minus', 'Equal', 'Backspace'],
  ['Tab', 'KeyQ', 'KeyW', 'KeyE', 'KeyR', 'KeyT', 'KeyY', 'KeyU', 'KeyI', 'KeyO', 'KeyP', 'BracketLeft', 'BracketRight', 'Backslash'],
  ['CapsLock', 'KeyA', 'KeyS', 'KeyD', 'KeyF', 'KeyG', 'KeyH', 'KeyJ', 'KeyK', 'KeyL', 'Semicolon', 'Quote', 'Enter'],
  ['ShiftLeft', 'KeyZ', 'KeyX', 'KeyC', 'KeyV', 'KeyB', 'KeyN', 'KeyM', 'Comma', 'Period', 'Slash', 'ShiftRight'],
  ['ControlLeft', 'MetaLeft', 'AltLeft', 'Space', 'AltRight', 'ControlRight', 'ArrowLeft', 'ArrowUp', 'ArrowDown', 'ArrowRight'],
];

const KEY_LABELS = {
  Backquote: '`', Minus: '-', Equal: '=', Backspace: '\u232b', Tab: '\u21e5',
  BracketLeft: '[', BracketRight: ']', Backslash: '\\', CapsLock: '\u21ea',
  Semicolon: ';', Quote: "'", Enter: '\u23ce', ShiftLeft: '\u21e7', ShiftRight: '\u21e7',
  Comma: ',', Period: '.', Slash: '/', ControlLeft: 'Ctrl', ControlRight: 'Ctrl',
  MetaLeft: '\u2295', AltLeft: 'Alt', AltRight: 'Alt', Space: 'Space',
  ArrowLeft: '\u2190', ArrowUp: '\u2191', ArrowDown: '\u2193', ArrowRight: '\u2192',
};

const labelFor = (code) => KEY_LABELS[code] || code.replace('Key', '').replace('Digit', '').replace('Numpad', 'Num ');

let pressedKeys = new Set();
let testedKeys = new Set();

builders.keyboard = () => {
  let html = '<p>Press each key in turn. Keys you have pressed turn green, so whatever ' +
    'stays grey is not working.</p><div class="row" style="flex-direction:column;align-items:flex-start">';
  for (const row of KEY_ROWS) {
    html += '<div class="row">';
    for (const code of row) {
      html += '<span class="key" data-code="' + code + '">' + labelFor(code) + '</span>';
    }
    html += '</div>';
  }
  html += '</div>';
  const remaining = KEY_ROWS.flat().filter((c) => !testedKeys.has(c)).length;
  html += '<p><span class="hint" id="key-progress">' + remaining + ' of ' +
    KEY_ROWS.flat().length + ' keys not yet pressed.</span></p>';
  return card('Press every key', html);
};

wire.keyboard = () => {
  paintKeys();
  window.addEventListener('keydown', keyDown);
  window.addEventListener('keyup', keyUp);
};

function releaseNotes() {
  window.removeEventListener('keydown', keyDown);
  window.removeEventListener('keyup', keyUp);
}

function keyDown(event) {
  pressedKeys.add(event.code);
  testedKeys.add(event.code);
  paintKeys();
}

function keyUp(event) {
  pressedKeys.delete(event.code);
  paintKeys();
}

function paintKeys() {
  document.querySelectorAll('.key').forEach((el) => {
    const code = el.dataset.code;
    el.classList.toggle('is-down', pressedKeys.has(code));
    el.classList.toggle('is-tested', testedKeys.has(code));
  });
  const progress = $('key-progress');
  if (progress) {
    const remaining = KEY_ROWS.flat().filter((c) => !testedKeys.has(c)).length;
    progress.textContent = remaining === 0
      ? 'Every key on the layout has been pressed.'
      : remaining + ' of ' + KEY_ROWS.flat().length + ' keys not yet pressed.';
  }
}

// Pointer ----------------------------------------------------------------

builders.pointer = () => card('Pointer and buttons',
  '<p>Move, click and drag inside the box. The path follows the pointer, so a ' +
  'cursor that jumps or drops out will show as a break.</p>' +
  '<p><canvas id="pointer-canvas" width="640" height="260"></canvas></p>' +
  '<p class="hint" id="pointer-state">Waiting for input.</p>') +
  card('What to check',
    bullet('The line should follow the pointer exactly, with no gaps.') +
    bullet('Click and drag should register on every part of the surface.'));

wire.pointer = () => {
  const canvas = $('pointer-canvas');
  const ctx = canvas.getContext('2d');
  let drawing = false;

  const clear = () => {
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = '#e3e7ec';
    for (let x = 0; x < canvas.width; x += 40) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke(); }
    for (let y = 0; y < canvas.height; y += 40) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke(); }
  };
  clear();

  const point = (event) => {
    const rect = canvas.getBoundingClientRect();
    return { x: event.clientX - rect.left, y: event.clientY - rect.top };
  };

  canvas.addEventListener('pointerdown', (event) => {
    drawing = true;
    clear();
    ctx.strokeStyle = '#1f6feb';
    ctx.lineWidth = 3;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    const p = point(event);
    ctx.moveTo(p.x, p.y);
    $('pointer-state').textContent = 'Button down at ' + Math.round(p.x) + ', ' + Math.round(p.y);
  });

  canvas.addEventListener('pointermove', (event) => {
    const p = point(event);
    if (drawing) {
      ctx.lineTo(p.x, p.y);
      ctx.stroke();
    }
    $('pointer-state').textContent = 'Pointer at ' + Math.round(p.x) + ', ' + Math.round(p.y) +
      (drawing ? ' \u2014 dragging' : '');
  });

  canvas.addEventListener('pointerup', () => {
    drawing = false;
    ctx.stroke();
    $('pointer-state').textContent = 'Released.';
  });
};

// Battery ----------------------------------------------------------------

builders.battery = () => card('Battery health',
  '<div id="battery-body" class="kv"><div class="k">Reading</div><div>\u2026</div></div>' +
  '<p class="row"><button id="battery-refresh">Refresh</button></p>') +
  card('What to look for',
    bullet('Health under 80% of design capacity is the usual service threshold.') +
    bullet('Charge should rise while plugged in and fall while on battery.'));

wire.battery = () => {
  $('battery-refresh').addEventListener('click', loadBattery);
  loadBattery();
};

function loadBattery() {
  bridge.battery().then((info) => {
    const body = $('battery-body');
    if (!info.ok) {
      body.innerHTML = '<div class="k">Unavailable</div><div>' + info.error + '</div>';
      return;
    }
    const rows = [
      ['Charge', info.chargePercent === null ? 'unknown' : info.chargePercent + '%'],
      ['Health', info.healthPercent ? info.healthPercent.toFixed(1) + '%' : 'not reported'],
      ['Design capacity', info.designCapacity ? info.designCapacity + ' mWh' : 'not reported'],
      ['Full charge capacity', info.fullChargeCapacity ? info.fullChargeCapacity + ' mWh' : 'not reported'],
      ['Cycle count', info.cycleCount === null ? 'not reported' : String(info.cycleCount)],
      ['Power line status', info.status === 2 ? 'connected to AC' : 'on battery'],
    ];
    body.innerHTML = rows.map(([k, v]) => '<div class="k">' + k + '</div><div>' + v + '</div>').join('');
  });
}

// Drives and storage ------------------------------------------------------

builders.drives = () => card('Drives',
  '<div class="kv" id="drive-list"><div class="k">Reading</div><div>\u2026</div></div>' +
  '<p class="row"><button id="drives-refresh">Refresh</button></p>') +
  card('Storage speed',
    '<p>Writes a temporary file, reads it back and deletes it.</p>' +
    '<div class="row"><button id="bench-run" class="primary">Run 64 MB test</button>' +
    '<span class="hint" id="bench-state"></span></div>' +
    '<div id="bench-result"></div>') +
  card('What to check',
    bullet('Plug in a USB stick and press Refresh: it should appear in the list.') +
    bullet('Write speed far below the drive\'s rating can point at a failing disk.'));

wire.drives = () => {
  $('drives-refresh').addEventListener('click', loadDrives);
  $('bench-run').addEventListener('click', runBenchmark);
  loadDrives();
};

function loadDrives() {
  bridge.drives().then((info) => {
    const list = $('drive-list');
    if (!info.ok) {
      list.innerHTML = '<div class="k">Unavailable</div><div>' + info.error + '</div>';
      return;
    }
    list.innerHTML = info.drives.map((d) =>
      '<div class="k">' + d.letter + ' ' + (d.name || '(no label)') + '</div>' +
      '<div>' + fmtBytes(d.freeBytes) + ' free of ' + fmtBytes(d.totalBytes) + '</div>').join('');
  });
}

function runBenchmark() {
  $('bench-state').textContent = 'Running\u2026';
  $('bench-result').innerHTML = '';
  bridge.storageBenchmark(64).then((result) => {
    if (!result.ok) {
      $('bench-state').textContent = 'Failed: ' + result.error;
      return;
    }
    $('bench-state').textContent = 'Done; the temporary file was removed.';
    $('bench-result').innerHTML =
      '<div class="kv">' +
      '<div class="k">Write</div><div>' + result.writeMBps.toFixed(0) + ' MB/s</div>' +
      '<div class="k">Read</div><div>' + result.readMBps.toFixed(0) + ' MB/s</div>' +
      '<div class="k">Read-back check</div><div class="' + (result.verified ? 'good' : 'bad') + '">' +
      (result.verified ? 'matched' : 'did not match') + '</div>' +
      '</div>';
  });
}

// Network ----------------------------------------------------------------

builders.network = () => card('Network interfaces',
  '<div class="kv" id="net-list"><div class="k">Reading</div><div>\u2026</div></div>' +
  '<p class="row"><button id="net-refresh">Refresh</button></p>') +
  card('What to check',
    bullet('A connected adapter should show a routable IPv4 address.') +
    bullet('Disconnect and press Refresh: that address should disappear.'));

wire.network = () => {
  $('net-refresh').addEventListener('click', loadNetwork);
  loadNetwork();
};

async function loadNetwork() {
  // The bridge is an async IPC call, so this is a promise, not an array.
  const rows = await bridge.network();
  $('net-list').innerHTML = (rows || []).map((r) =>
    '<div class="k">' + r.name + ' \u2014 ' + r.family + '</div><div class="mono">' +
    r.address + (r.internal ? ' (internal)' : '') + '</div>').join('') ||
    '<div class="k">Interfaces</div><div>none reported</div>';
}

// Guided pass -------------------------------------------------------------

function renderBanner() {
  const banner = $('banner');
  banner.hidden = !guided.active;
  if (!guided.active) return;
  const check = guidedOrder[guided.index];
  $('banner-step').textContent = 'Check ' + (guided.index + 1) + ' of ' + guidedOrder.length;
  $('banner-title').textContent = check.title;
  $('banner-next').textContent = guided.index === guidedOrder.length - 1 ? 'Finish' : 'Next check';
  $('banner-back').disabled = guided.index === 0;
}

$('run-all').addEventListener('click', () => {
  guided = { active: true, index: 0 };
  select(guidedOrder[0].id);
});

$('banner-next').addEventListener('click', () => {
  if (guided.index === guidedOrder.length - 1) {
    guided.active = false;
    select('overview');
    return;
  }
  guided.index += 1;
  select(guidedOrder[guided.index].id);
});

$('banner-back').addEventListener('click', () => {
  if (guided.index > 0) {
    guided.index -= 1;
    select(guidedOrder[guided.index].id);
  }
});

$('banner-exit').addEventListener('click', () => {
  guided.active = false;
  select('overview');
});

// Outcome controls --------------------------------------------------------

$('result').addEventListener('change', (event) => {
  if (current === 'overview') return;
  results[current] = { ...(results[current] || {}), status: event.target.value };
  save();
  renderNav();
});

$('notes').addEventListener('input', (event) => {
  if (current === 'overview') return;
  results[current] = { ...(results[current] || {}), note: event.target.value };
  save();
});

// Report -----------------------------------------------------------------

function reportText() {
  const lines = ['# Checkup report', ''];
  lines.push('**' + (systemSnapshot || 'Machine details unavailable') + '**');
  lines.push('');
  lines.push('| Check | Result | Notes |');
  lines.push('| --- | --- | --- |');
  for (const check of guidedOrder) {
    const note = noteOf(check.id).replace(/\|/g, '\\|');
    lines.push('| ' + check.title + ' | ' + statusOf(check.id) + ' | ' + note + ' |');
  }
  lines.push('');
  return lines.join('\n');
}

let systemSnapshot = null;

bridge.systemInfo().then((info) => {
  systemSnapshot = info.platformName + ' ' + info.release + ' (' + info.arch + '), ' +
    info.cpu + ', ' + fmtBytes(info.memoryBytes) + ' RAM';
});

// Start -------------------------------------------------------------------

renderNav();
select('overview');
