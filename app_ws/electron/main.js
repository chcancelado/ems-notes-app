const { app, BrowserWindow } = require('electron');
const path = require('path');
const express = require('express');

function getWebRoot() {
  if (app.isPackaged) {
    // `extraResources` will place Flutter web here
    return path.join(process.resourcesPath, 'build', 'web');
  }
  // In dev, Flutter web build output lives at repoRoot/build/web
  return path.join(__dirname, '..', 'build', 'web');
}

/**
 * Flutter web builds expect to be hosted from a web server (base href is "/").
 * Serving from a local HTTP server avoids file:// path issues.
 */
function startStaticServer(webRoot) {
  const serverApp = express();
  serverApp.use(express.static(webRoot));

  // Flutter web uses client-side routing; fall back to index.html
  serverApp.get('*', (_req, res) => {
    res.sendFile(path.join(webRoot, 'index.html'));
  });

  return new Promise((resolve, reject) => {
    const server = serverApp.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolve({ server, port: address.port });
    });
    server.on('error', reject);
  });
}

let serverHandle = null;

async function createWindow() {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  const webRoot = getWebRoot();
  const { server, port } = await startStaticServer(webRoot);
  serverHandle = server;

  win.loadURL(`http://127.0.0.1:${port}/`);

  // Avoid new-window surprises
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (serverHandle) {
    try {
      serverHandle.close();
    } catch (_) {
      // ignore
    }
    serverHandle = null;
  }
  if (process.platform !== 'darwin') app.quit();
});
