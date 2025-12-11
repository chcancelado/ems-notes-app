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

# Demo (No Flutter Install): Electron Wrapper

This repo includes an Electron wrapper that packages the Flutter Web build into a desktop app for stakeholders who don't have Flutter installed.

**Environment variables**: The build script (`electron/scripts/build_flutter_web.js`) reads `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `OPENAI_API_KEY` from your `.env` and bakes them into the web build via `--dart-define`. These keys are **embedded in the demo bundle** (including the OpenAI key) — use disposable/restricted keys for stakeholder demos.

## Run locally (developer)

```zsh
cd electron
npm install
npm run start
```

## Create distributable app for stakeholders

**macOS** (creates a `.dmg` + `.zip`):

```zsh
cd electron
npm install
npm run dist:mac
```

**Windows** (requires Windows machine or CI):

```cmd
cd electron
npm install
npm run dist:win
```

**Linux** (requires Linux machine or CI):

```bash
cd electron
npm install
npm run dist:linux
```

Outputs land in `electron/dist/`.

## Automated builds via GitHub Actions

The repo includes a CI workflow (`.github/workflows/build-electron.yml`) that automatically builds **both macOS and Windows** installers when you push to `feature/executable` or `main`.

**Setup (one-time)**:
1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Add repository secrets:
   - `SUPABASE_URL` — Your Supabase project URL
   - `SUPABASE_ANON_KEY` — Your Supabase anon key
   - `OPENAI_API_KEY` — OpenAI API key (use a restricted key for demos)

**Download installers**:
1. Push your changes to `feature/executable` or `main`
2. Go to **Actions** tab in GitHub
3. Click the latest workflow run
4. Download artifacts:
   - `ems-notes-demo-macos` — Contains `.dmg` and `.zip` for macOS
   - `ems-notes-demo-windows` — Contains `.exe` installer and `.zip` for Windows
   - `ems-notes-demo-linux` — Contains `.AppImage` (run directly) and `.zip` for Linux 