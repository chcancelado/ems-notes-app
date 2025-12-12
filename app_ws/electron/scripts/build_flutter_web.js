#!/usr/bin/env node
/**
 * Build script for Electron wrapper: reads ../.env and injects only safe
 * environment variables (SUPABASE_URL, SUPABASE_ANON_KEY, OPENAI_API_KEY)
 * into the Flutter web build via --dart-define.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Read .env from repo root
const envPath = path.join(__dirname, '..', '..', '.env');
const envVars = {};

if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8');
  envContent.split('\n').forEach((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;
    const [key, ...valueParts] = trimmed.split('=');
    if (key && valueParts.length > 0) {
      envVars[key.trim()] = valueParts.join('=').trim();
    }
  });
}

// Build --dart-define args for keys needed by the Electron demo
const allowedKeys = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'OPENAI_API_KEY'];
const dartDefines = allowedKeys
  .filter((k) => envVars[k])
  .map((k) => `--dart-define=${k}=${envVars[k]}`);

// Construct flutter build web command
const flutterArgs = [
  'build',
  'web',
  '--release',
  '--pwa-strategy=none',
  '--no-web-resources-cdn',
  '--no-tree-shake-icons',
  ...dartDefines,
];

console.log('[build_flutter_web] Running:', `flutter ${flutterArgs.join(' ')}`);

try {
  execSync(`flutter ${flutterArgs.join(' ')}`, {
    cwd: path.join(__dirname, '..', '..'),
    stdio: 'inherit',
  });
  console.log('[build_flutter_web] Flutter web build succeeded.');
} catch (err) {
  console.error('[build_flutter_web] Flutter web build failed:', err.message);
  process.exit(1);
}
