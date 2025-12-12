# Motivation 

As a volunteer firefighter, I respond to a lot of EMS calls even though I don't have formal EMS training. On many of these calls, I feel the gap between what I can do safely and what would help the patient or the incoming EMS crew. Right now, I rely on memory or quick notes, but it feels unstructured and easy to miss details. I want a way to better capture patient information and provide meaningful support without stepping outside my training.

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

## Download Pre-built Desktop Apps

The easiest way to run this app is to download pre-built installers from GitHub Actions:

1. Go to the [Build Electron Demo workflow run](https://github.com/chcancelado/ems-notes-app/actions/runs/20153605800#artifacts)
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

## Getting Started with the Demo

Once you have the app running, here's how to use it:

### 1. Create an Account

- Click **"Sign Up"** on the welcome screen
- Enter your email and create a password
- **Agency Code**: Enter any code you like (e.g., "DEMO2025")
  - This code groups users together for report sharing
  - Use the same agency code across multiple test accounts to demo collaboration features

### 2. Log In

- Use the email and password you just created
- You'll be taken to the home screen

### 3. Start a New Session

- Click **"New Session"** from the home screen
- Fill in incident details:
  - **Incident Type**: Medical, Fire, Vehicle, etc.
  - **Location**: Address of the incident
  - **Date & Time**: When you arrived

### 4. Record Patient Information

- **Patient Info tab**: Enter demographics, contact info, medical history
- **Vitals tab**: Record vital signs (heart rate, blood pressure, etc.)
  - Add multiple readings over time
- **AI Assistant**: Click the chat icon to get contextual suggestions and protocol reminders

### 5. Generate and Share Reports

- Once you've recorded information, the app auto-generates a professional report
- **Share Report**: Send via email or export as PDF
- **Test Collaboration**: Create multiple accounts with the same agency code, then share reports between them to see how teams can collaborate

### Tips for Testing

- Create 2-3 test accounts with the same agency code to demo the sharing features
- Try different incident types to see how the AI assistant adapts its suggestions
- Record multiple vitals readings to see the tracking over time
- Use the chatbot to ask questions like "What should I check first for this type of incident?"

## Run Locally (Development Mode)

**Requirements:**
- Node.js v20 or later ([Download](https://nodejs.org/))

**Steps:**
```bash
cd app_ws/electron
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
cd app_ws/electron
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

Installers will be created in `app_ws/electron/dist/`.

## Automated Builds (CI/CD)

This repository includes a GitHub Actions workflow that automatically builds desktop apps for all platforms when code is pushed.

**Setup (for repository maintainers):**
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Add these secrets:
   - `SUPABASE_URL` — Supabase project URL
   - `SUPABASE_ANON_KEY` — Supabase anonymous key
   - `OPENAI_API_KEY` — OpenAI API key

The workflow automatically triggers on pushes to `feature/executable` or `main` branches.

---

# Build Flutter App Directly

If you want to build and run the native Flutter app (for mobile or development):

## Install Flutter

1. Download Flutter SDK: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
2. Follow the installation guide for your operating system
3. Verify installation: `flutter doctor`

## Run the App

**Create .env file** (in `app_ws/` directory):
```bash
SUPABASE_URL=https://vhcxbsmqnwuuhizhrlmt.supabase.co
SUPABASE_ANON_KEY=<your-key>
OPENAI_API_KEY=<your-key>
```

**Run on different platforms:**

```bash
cd app_ws

# Run on web browser
flutter run -d chrome

# Run on iOS simulator (macOS only)
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on desktop (macOS)
flutter run -d macos

# Run on desktop (Windows)
flutter run -d windows

# Run on desktop (Linux)
flutter run -d linux
```

**Build release versions:**

```bash
cd app_ws

# Build web
flutter build web

# Build iOS (macOS only, requires Xcode)
flutter build ios

# Build Android APK
flutter build apk

# Build Android App Bundle (for Play Store)
flutter build appbundle

# Build macOS desktop app
flutter build macos

# Build Windows desktop app
flutter build windows

# Build Linux desktop app
flutter build linux
```

Built apps will be in `app_ws/build/` directory.
