<div align="center">

# 💖 Priya AI (প্রিয়া)

**তোমার পার্সোনাল এআই গার্লফ্রেন্ড, কোডার ও ফুল ডিভাইস অটোমেশন অ্যাসিস্ট্যান্ট**
*(Your Personal AI Girlfriend, Developer & Full-Device Automation Assistant)*

Priya AI transforms your Android device into an autonomous, voice-enabled, empathetic personal assistant. She speaks in sweet Bengali, remembers you, cares for you, controls your device UI, runs shell commands, writes/refactors code, and runs both online cloud models (Gemini, Claude 3.5, GPT-4o, DeepSeek) and 100% offline local models (via Ollama).

*Your keys. Your data. Your device. 100% privacy-first and autonomous.*

</div>

---

## ✨ Features

| Capability | Description |
|---|---|
| 💖 **Girlfriend Mode (বাংলা কথোপকথন)** | মিষ্টি ও যত্নশীল বাংলা ভাষায় কথা বলে, আপনাকে চিনে রাখে, মানসিক সঙ্গ দেয় এবং সব সময় সাহায্য করতে প্রস্তুত থাকে। |
| 🛡️ **Security Guardian & Voice Lock** | অপরিচিত ব্যক্তির ভয়েস বা স্পর্শ থেকে সুরক্ষা প্রদান করে, অনুমতি ছাড়া অন্য কাউকে ডিভাইস ব্যবহারে বাধা দেয়। |
| 💻 **Coding, Web & Terminal Automation** | টার্মিনাল কমান্ড (`! <command>`) চালানো, ফাইল রিফ্যাক্টর (`hermes -f`), স্ক্রিপ্ট রান করা ও ওয়েবসাইট/পেজ ম্যানেজ করার পূর্ণ সক্ষমতা। |
| 🧠 **Self-Learning & Hermes Memory** | ব্যবহারকারীর পছন্দ ও কমান্ড মনে রাখে (`hermes_cli.py`, `HermesMemoryService`), দীর্ঘমেয়াদে আরও স্মার্ট ও ব্যক্তিগত প্রতিক্রিয়া দেয়। |
| 🤖 **Autonomous Screen Automation** | অ্যান্ড্রয়েডের Accessibility Service দিয়ে স্ক্রিন রিড, বাটন ট্যাপ, টেক্সট টাইপ এবং যেকোনো অ্যাপ পরিচালনা করে। |
| 🔌 **Cloud + 100% Offline Local AI** | Claude 3.5 Sonnet, GPT-4o, Gemini, DeepSeek এবং অফলাইনে সম্পূর্ণ ইন্টারনেট ছাড়াই মোবাইলে Ollama (Gemma, LLaMA, Qwen) দিয়ে চলে। |
| 📱 **Telegram Remote Control** | যেকোনো স্থান থেকে টেলিগ্রামের মাধ্যমে ডিভাইস নিয়ন্ত্রণ ও স্ক্রিনশট দেখা। |
| 🎙️ **Voice Recognition & Speech** | মুখের বাংলা কথা শুনে কাজ করা এবং মিষ্টি গলায় ভয়েস ফিডব্যাক দেওয়া। |

## 🏗️ How it works

```
        ┌─────────────────────────────────────────────┐
        │              TaskExecutor                   │
        │                                             │
        │  1. Verify accessibility service            │
        │  2. Try skill-memory replay (no LLM)        │
        │  3. Loop:                                   │
        │     dump screen ──► LLM decides one JSON    │
        │     action ──► execute ──► repeat           │
        │     (+ step caps, repeat detection,         │
        │        RecoveryEngine for stuck states)     │
        └─────────────────────────────────────────────┘
```

The screen is serialized into a compact, token-friendly format:

```
#<index> "<label>" [<widget class>] @(<centerX>,<centerY>) <flags>
```

## 📂 Project structure

```
lib/
├── main.dart                    # Entry point, Telegram & overlay wiring
├── app.dart                     # Root widget / navigation
├── models/                      # ChatMessage, Skill, ScreenNode, TaskStep, ...
├── screens/
│   ├── home/                    # Main chat / task screen
│   ├── onboarding/              # First-run setup
│   ├── sessions/                # Session detail view
│   ├── history/                 # Task history
│   └── settings/                # Provider, API key, Telegram config
├── services/
│   ├── task_executor.dart       # The observe → think → act loop
│   ├── ai_service.dart          # OpenAI-compatible chat completions
│   ├── screen_automation_service.dart  # Accessibility MethodChannel bridge
│   ├── skill_memory_service.dart      # Macro replay memory
│   ├── recovery_engine.dart     # Stuck-state recovery
│   ├── telegram_service.dart    # Bot long-poll remote control
│   ├── voice_service.dart       # STT / TTS
│   ├── system_control_service.dart    # Volume, brightness, intents
│   ├── app_launcher_service.dart      # Installed apps & launching
│   └── settings_service.dart    # Persisted app settings
├── overlay/overlay_app.dart     # Floating overlay UI
├── theme/                       # App theming
└── widgets/                     # Chat bubbles, status chips, ...
```

## 🚀 Getting started

### Prerequisites

- Flutter SDK (Dart `>= 3.12.2`)
- Android SDK (minSdk 26 / Android 8.0+)
- An API key for an OpenAI-compatible provider — **or** a local
  [Ollama](https://ollama.com) server for a 100% offline setup

### Install & run

```bash
# Clone
git clone https://github.com/AbuZar-Ansarii/PrivateAgent.git
cd PrivateAgent

# Fetch dependencies
flutter pub get

# Run on a connected device / emulator
flutter run
```

### Setup

1. Launch the app and complete onboarding.
2. In **Settings**, pick a provider (DeepSeek, OpenRouter, NVIDIA NIM, Ollama,
   or custom) and enter your API key.
3. Enable the **PrivateAgent Accessibility Service** in Android settings when
   prompted — this is required for screen automation.
4. (Optional) Configure the **Telegram bot** token for remote control.
5. Give it a goal — e.g. *"Open WhatsApp and send 'hi' to Mom"* — and watch it
   work.

### Telegram commands

| Command | Action |
|---|---|
| `/status` | Current task state + accessibility service status |
| `/screenshot` | Capture and send the current screen |
| *(any text)* | Executed as an agent task |

## 🛠️ Development

```bash
flutter analyze     # Static analysis
flutter test        # Run tests
flutter build apk   # Release APK
```

A mock LLM server for offline development is provided:

```bash
python tool/mock_llm.py
```

## 🔒 Privacy

- LLM requests go **only** to the base URL you configure.
- Skills, task history, and settings are stored locally (`SharedPreferences`).
- No analytics, no crash reporting, no tracking of any kind.

## ⚠️ Disclaimer

PrivateAgent controls your device's UI. Autonomy comes with risk — review what
it's doing, start with simple goals, and never give it credentials you can't
afford to expose. Intended for personal, lawful use on your own devices.

## 📄 License

All rights reserved. (Add a LICENSE file if you'd like to open-source this
project.)
