# Motivation 

As a volunteer firefighter, I respond to a lot of EMS calls even though I don’t have formal EMS training. On many of these calls, I feel the gap between what I can do safely and what would help the patient or the incoming EMS crew. Right now, I rely on memory or quick notes, but it feels unstructured and easy to miss details. I want a way to better capture patient information and provide meaningful support without stepping outside my training. 

 

# Purpose 

The idea is a mobile app that: 

1. Guides non-EMS responders in collecting structured patient information and vitals. 

2. Provides safe, low-level care reminders rooted in established first aid and baseline EMS protocols. 

3. Generates a clear, shareable report to make handoffs to EMS teams smoother and more reliable. 

The goal is not to diagnose or replace EMS providers, but to bridge the gap between first-arrival responders and advanced care, while improving communication and consistency. 

 

## Scope of Care Examples 

The app would focus on non-consequential, low-risk interventions such as: 

* *Positioning*: recovery position, keeping stroke patients upright, elevating legs in suspected shock. 

* *Comfort measures*: covering for warmth, encouraging calm breathing, monitoring changes. 

* *Basic first aid*: bleeding control, burn cooling and dressing, immobilizing an injured limb. 

* *Protocol reminders*: FAST stroke check, noting last known well time, SAMPLE/OPQRST history prompts. 

* *Vital tracking*: structured entry for heart rate, breathing, and repeating over time. 

 

## Boundaries 

* No medication dosing or administration guidance. 

* No invasive procedures. 

* No diagnostic claims. 

* Framed strictly as checklists, reminders, and documentation tools.


---

# Desktop App (No Flutter Install Required)

This project includes an Electron wrapper that packages the Flutter Web app into a standalone desktop application that runs without requiring Flutter installation.

**⚠️ Security Note**: API keys (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `OPENAI_API_KEY`) are embedded in the desktop build. Use restricted or disposable keys for distribution.

## Download Pre-built Desktop Apps

The easiest way to run this app is to download pre-built installers from GitHub Actions:

1. Go to the [Actions tab](https://github.com/collin-sager/ems-notes-app/actions)
2. Click the latest **"Build Electron Demo"** workflow run
3. Download the artifact for your platform:
   - **macOS Apple Silicon** (M1/M2/M3/M4): `ems-notes-demo-macos-arm64` — Contains `.dmg` and `.zip`
   - **macOS Intel**: `ems-notes-demo-macos-intel` — Contains `.dmg` and `.zip`
   - **Windows**: `ems-notes-demo-windows` — Contains `.exe` installer and `.zip`
   - **Linux**: `ems-notes-demo-linux` — Contains `.AppImage` (portable) and `.zip`

### macOS Security Notice

Since the app isn't signed with an Apple Developer certificate, macOS will block it on first launch:

1. **Right-click** (or Control+click) on **EMS Notes Demo**
2. Select **"Open"**
3. Click **"Open"** in the security dialog
4. The app will now run normally (only needed once)

## Run Locally (Development Mode)

**Requirements:**
- Node.js v20 or later ([Download](https://nodejs.org/))

**Steps:**
```bash
cd electron
npm install
npm run start
```

## Build Desktop Apps Locally

**Requirements:**
- Node.js v20 or later ([Download](https://nodejs.org/))
- Flutter v3.35.4 or compatible ([Download](https://flutter.dev/docs/get-started/install))

**Create .env file** (in `app_ws/` directory):
```bash
SUPABASE_URL=https://vhcxbsmqnwuuhizhrlmt.supabase.co
SUPABASE_ANON_KEY=<your-key>
OPENAI_API_KEY=<your-key>
```

**Build for your platform:**

```bash
# macOS (auto-detects architecture)
cd electron
npm install
npm run dist:mac

# macOS Apple Silicon specifically
npm run dist:mac:arm64

# macOS Intel specifically
npm run dist:mac:x64

# Windows (requires Windows machine)
npm run dist:win

# Linux (requires Linux machine)
npm run dist:linux
```

Installers will be created in `electron/dist/`.

## Automated Builds (CI/CD)

This repository includes a GitHub Actions workflow that automatically builds desktop apps for all platforms when code is pushed.

**Setup (for repository maintainers):**
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Add these secrets:
   - `SUPABASE_URL` — Supabase project URL
   - `SUPABASE_ANON_KEY` — Supabase anonymous key
   - `OPENAI_API_KEY` — OpenAI API key

The workflow automatically triggers on pushes to `feature/executable` or `main` branches. 