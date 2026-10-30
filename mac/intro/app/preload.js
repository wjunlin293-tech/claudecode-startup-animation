const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('intro', {
  covered: () => ipcRenderer.send('covered'),
  ready: (hasCover) => ipcRenderer.send('ready', !!hasCover),
  getSnapshot: () => ipcRenderer.invoke('get-snapshot'),
  onRect: (cb) => ipcRenderer.on('rect', (_e, payload) => cb(payload)),
  skip: () => ipcRenderer.send('skip'),
  setClickable: (on) => ipcRenderer.send('clickable', !!on),
});
