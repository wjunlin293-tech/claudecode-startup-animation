const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('intro', { covered: () => ipcRenderer.send('covered') });
