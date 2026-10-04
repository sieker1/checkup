// Bridge between the renderer and the OS-facing work in main.js. Context
// isolation stays on, so the renderer only gets these named calls.

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('fettle', {
  systemInfo: () => ipcRenderer.invoke('system:info'),
  storageBenchmark: (megabytes) => ipcRenderer.invoke('storage:benchmark', megabytes),
  battery: () => ipcRenderer.invoke('battery:info'),
  drives: () => ipcRenderer.invoke('drives:list'),
  network: () => ipcRenderer.invoke('network:interfaces'),
});
