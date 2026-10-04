// Checkup for Windows.
//
// The only OS-specific work lives here, behind IPC: WMI queries via PowerShell,
// a disk speed test on the temp volume, and the plain Node facts. Everything
// else (display, audio, microphone, camera, keyboard, pointer) is browser API
// work in the renderer, so it behaves the same on any platform and can be
// exercised on a Mac during development.

const { app, BrowserWindow, ipcMain } = require('electron');
const { execFile } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const isWindows = process.platform === 'win32';

function createWindow() {
  const win = new BrowserWindow({
    width: 1020,
    height: 720,
    minWidth: 900,
    minHeight: 620,
    title: 'Checkup',
    backgroundColor: '#f4f5f7',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  return win;
}

/// Runs a PowerShell snippet and resolves its stdout. Rejects with the stderr
/// text so the renderer can show something useful rather than a blank field.
function powershell(script) {
  return new Promise((resolve, reject) => {
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
      { windowsHide: true, timeout: 20000 },
      (error, stdout, stderr) => {
        if (error) reject(new Error((stderr || error.message).trim()));
        else resolve(stdout.trim());
      }
    );
  });
}

/// WMI returns most numeric fields as strings; normalise what we can.
function number(value) {
  if (value === null || value === undefined) return null;
  const n = Number(String(value).trim());
  return Number.isFinite(n) ? n : null;
}

function registerIpc() {
  ipcMain.handle('system:info', () => ({
    platform: process.platform,
    platformName: isWindows ? 'Windows' : process.platform === 'darwin' ? 'macOS' : 'Linux',
    release: os.release(),
    arch: process.arch,
    hostname: os.hostname(),
    cpu: (os.cpus()[0] || {}).model || 'Unknown CPU',
    cores: os.cpus().length,
    memoryBytes: os.totalmem(),
    isWindows,
  }));

  ipcMain.handle('storage:benchmark', async (_event, megabytes) => {
    const size = Math.max(1, Number(megabytes) || 64) * 1000 * 1000;
    const file = path.join(os.tmpdir(), 'checkup-speedtest.bin');

    // A repeating pattern rather than zeros, so the read-back check means
    // something.
    const payload = Buffer.allocUnsafe(size);
    for (let i = 0; i < size; i += 1) payload[i] = i & 0xff;

    const writeStart = process.hrtime.bigint();
    try {
      fs.writeFileSync(file, payload);
    } catch (error) {
      return { ok: false, error: error.message };
    }
    const writeSeconds = Number(process.hrtime.bigint() - writeStart) / 1e9;

    const readStart = process.hrtime.bigint();
    let read;
    try {
      read = fs.readFileSync(file);
    } catch (error) {
      return { ok: false, error: error.message };
    }
    const readSeconds = Number(process.hrtime.bigint() - readStart) / 1e9;

    try { fs.unlinkSync(file); } catch { /* the temp file is best-effort */ }

    return {
      ok: true,
      megabytes: Math.round(size / 1000 / 1000),
      writeMBps: size / 1000 / 1000 / Math.max(writeSeconds, 1e-6),
      readMBps: size / 1000 / 1000 / Math.max(readSeconds, 1e-6),
      verified: read.length === size && read.equals(payload),
    };
  });

  ipcMain.handle('battery:info', async () => {
    if (!isWindows) return { ok: false, error: 'Battery readings come from WMI, so this needs Windows.' };
    try {
      const raw = await powershell(
        'Get-CimInstance Win32_Battery | Select-Object -First 1 ' +
        'EstimatedChargeRemaining,BatteryStatus,DesignCapacity,FullChargeCapacity,CycleCount | ConvertTo-Json -Compress'
      );
      if (!raw) return { ok: false, error: 'No battery reported by WMI.' };
      const data = JSON.parse(raw);
      const design = number(data.DesignCapacity);
      const full = number(data.FullChargeCapacity);
      return {
        ok: true,
        chargePercent: number(data.EstimatedChargeRemaining),
        status: number(data.BatteryStatus),
        designCapacity: design,
        fullChargeCapacity: full,
        cycleCount: number(data.CycleCount),
        healthPercent: design && full ? (full / design) * 100 : null,
      };
    } catch (error) {
      return { ok: false, error: error.message };
    }
  });

  ipcMain.handle('drives:list', async () => {
    if (!isWindows) return { ok: false, error: 'Drive enumeration uses WMI, so this needs Windows.' };
    try {
      const raw = await powershell(
        'Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,Size,FreeSpace,DriveType | ConvertTo-Json -Compress'
      );
      const parsed = JSON.parse(raw || '[]');
      const list = Array.isArray(parsed) ? parsed : [parsed];
      return {
        ok: true,
        drives: list.map((d) => ({
          letter: d.DeviceID,
          name: (d.VolumeName || '').trim(),
          totalBytes: number(d.Size),
          freeBytes: number(d.FreeSpace),
          driveType: number(d.DriveType),
        })),
      };
    } catch (error) {
      return { ok: false, error: error.message };
    }
  });

  ipcMain.handle('network:interfaces', () => {
    const interfaces = os.networkInterfaces();
    const rows = [];
    for (const [name, addresses] of Object.entries(interfaces)) {
      for (const address of addresses || []) {
        rows.push({
          name,
          family: address.family,
          address: address.address,
          internal: address.internal,
        });
      }
    }
    return rows;
  });
}

app.whenReady().then(() => {
  registerIpc();
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
