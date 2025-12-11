const { app, BrowserWindow } = require('electron');
const path = require('path');
const express = require('express');

// Work around GPU/ANGLE driver issues that can cause a blank window.
// Must be set before app 'ready'.
// NOTE: Do not fully disable GPU here (CanvasKit needs WebGL). Instead force a
// software implementation via SwiftShader.
app.commandLine.appendSwitch('ignore-gpu-blocklist');
app.commandLine.appendSwitch('use-angle', 'swiftshader');
app.commandLine.appendSwitch('use-gl', 'swiftshader');

function log(...args) {
  // eslint-disable-next-line no-console
  console.log('[electron]', ...args);
}

function logError(...args) {
  // eslint-disable-next-line no-console
  console.error('[electron]', ...args);
}

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
    backgroundColor: '#ffffff',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (!isMainFrame) return;
    logError('did-fail-load', { errorCode, errorDescription, validatedURL });
  });

  win.webContents.on('render-process-gone', (_event, details) => {
    logError('render-process-gone', details);
  });

  win.webContents.on('console-message', (_event, level, message, line, sourceId) => {
    // Mirror browser console to terminal (helps debug blank screens).
    const lvl = ['debug', 'info', 'warn', 'error'][level] ?? String(level);
    log(`console.${lvl}: ${message} (${sourceId}:${line})`);
  });

  const webRoot = getWebRoot();
  log('webRoot:', webRoot);
  const { server, port } = await startStaticServer(webRoot);
  serverHandle = server;

  log('serving Flutter web at:', `http://127.0.0.1:${port}/`);

  await win.loadURL(`http://127.0.0.1:${port}/`);

  if (!app.isPackaged) {
    win.webContents.openDevTools({ mode: 'detach' });
  }

  // Avoid new-window surprises
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
}

app.whenReady().then(async () => {
  try {
    await createWindow();
  } catch (e) {
    logError('Failed to create window:', e);
    app.quit();
    return;
  }

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
