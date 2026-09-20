# Agenda Inteligente Acessivel (SeniorCare Voice)

Voice-driven smart agenda for elderly people and caregivers with real-time alarms, AI schedule corrections and offline mode. Built with React, Express, TypeScript, Google Gemini and a Flutter companion app.

## Features

- **Voice-First Interaction:** 100% natural voice commands with two-step confirmation ("I will schedule your appointment at 8 AM. Say Yes to confirm or No to cancel").
- **24h Real-Time Alarms with Voice Dismissal:** Alarms trigger at the scheduled time, vibrate the device, announce the task name and can be dismissed by voice ("Dismiss", "Done", "Ok").
- **Flexible Timeline via Voice:** Relative scheduling ("take water in 3 minutes", "in 2 hours/days"), monthly recurrence ("company meeting every 10th") and advance reminders ("remind me 3 days before").
- **Google Gemini AI + Offline Parser:** Corrects time confusions and generates daily summaries with contextual task information.
- **Embedded Phone Simulator:** Test the exact smartphone experience directly in the browser.
- **Emergency / Caregiver Button:** Quick alert dispatch and direct dial to the registered caregiver.
- **Spoken Weekly Calendar:** Tap any day of the week to hear the scheduled commitments.
- **Offline-First Mode:** Full functionality without internet connection using local data persistence.

## Prerequisites

- Node.js 18+
- (Optional) Flutter SDK for native mobile app

## Running the Web App (React + Express + Gemini)

```bash
npm install
npm run dev        # Development server on port 3000
npm run build      # Production build
npm start          # Start production build
```

## Running the Flutter Companion App

```bash
cd flutter
flutter pub get
flutter run                   # Run on device/emulator
flutter build apk --release   # Build Android APK
```

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React, TypeScript, Tailwind CSS |
| Backend | Express, Node.js |
| AI | Google Gemini API, offline parser |
| Mobile | Flutter (Android/iOS companion) |
| Data | Local storage, offline-first persistence |
