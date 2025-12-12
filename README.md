Termux Telegram Bot (Android 12–15 Supported)

A powerful remote-control bot for Android using Termux + Telegram.
Control your phone from anywhere — camera, mic, files, audio play, WiFi scan, apps, location, everything.

⚠️ SECURITY WARNING
Never upload your real Telegram BOT TOKEN or CHAT ID on GitHub.
Use placeholders like:

BOT_TOKEN="PASTE_YOUR_BOT_TOKEN_HERE"
CHAT_ID="PASTE_YOUR_CHAT_ID_HERE"


---
## 📦 Installation (One-Command Setup)

Termux bot install karna bahut easy hai.  
Sirf yeh command run karo:

```bash
curl -L -o install.sh https://raw.githubusercontent.com/yuvraj15082007-ctrl/termux-telegram-bot/main/install.sh && bash install.sh
```

---

## ⚙️ Initial Setup

Install hone ke baad:

1. `~/termux-telegram-bot/bot.sh` file open karo  
2. Yeh do lines update karo:

```bash
BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
```

---

## ▶️ Start Bot

```bash
cd ~/termux-telegram-bot
./bot.sh
```

---

## 🆔 How to Get BOT TOKEN & CHAT ID?

### 1️⃣ BOT TOKEN
- Telegram par **@BotFather** open karo
- `/newbot` → name → username
- BotFather tumhe token dega → Copy karo

### 2️⃣ CHAT ID
- Telegram par @myidbot open karo
- `/getid` send karo  
- Jo number mile wo tumhara chat ID hai
🚀 Features

🎥 Media & Camera

• /photo back – Take photo from back camera
• /photo front – Take photo from front camera
• /lastphoto – Send last clicked photo
• /lastvideo – Send last recorded video
• /audio – Record 30s microphone audio
• /screen 10 – Screen record for 10 seconds


---

📂 Files & Storage

• /ls [path] – List files
• /sendfile [path] – Download a file
• /zipphotos [N] – Zip last N camera photos
• /storage – Internal + External storage info


---

📡 Network

• /ip – Public + Local IP
• /speed – Internet speedtest
• /ping [host] – Ping test
• /wifiscan – Scan nearby WiFi networks


---

📱 System Info

• /status – Battery percentage
• /heat – Battery temperature
• /info – Model + Android version + Uptime
• /apps – List installed apps
• /clip – Read clipboard text


---

🔧 Controls

• /speak [text] – TTS Speak
• /torch on/off – Flashlight
• /vibrate [ms] – Vibration
• /ring [sec] – Ring phone
• /vol max/mute/0–15 – Volume control
• /play [song] – Play audio file
• /autoplay [folder] – Auto-continue playing songs
• /stopautoplay – Stop autoplay
• /stop – Stop media player


---

⚙️ Bot Control

• /restart – Restart bot safely
• /help – Show command list


---

🛠️ Requirements (Install in Termux)

pkg install termux-api jq ffmpeg zip curl python
pip install speedtest-cli
termux-setup-storage

Give required permissions: • Camera
• Microphone
• Storage
• Location


---

🤖 Telegram Bot Setup

1️⃣ Create Bot Token

1. Open Telegram → search "@BotFather"


2. Send: /newbot


3. Give bot name + user name


4. BotFather will give BOT TOKEN



Paste the token in bot.sh:

BOT_TOKEN="PASTE_YOUR_BOT_TOKEN_HERE"


---

2️⃣ Get Chat ID

1. Send /start to your bot


2. Open in browser:



https://api.telegram.org/botYOUR_TOKEN/getUpdates

3. Look for:



"chat": { "id": 123456789 }

Use that number:

CHAT_ID="PASTE_YOUR_CHAT_ID_HERE"


---

▶️ How to Run Bot

chmod +x bot.sh
./bot.sh

Your bot will go online on Telegram immediately.


---

📘 Full Command List

📍 Location
/loc

📸 Camera
/photo back
/photo front
/lastphoto
/lastvideo

🎙 Audio
/audio
/screen [seconds]

📂 Files
/ls [path]
/sendfile [path]
/zipphotos [N]
/storage

🌐 Network
/ip
/ping [host]
/speed
/wifiscan

📱 System Info
/status
/heat
/info
/apps
/clip

🔧 Controls
/speak [text]
/torch on/off
/vibrate [ms]
/ring [sec]
/vol max/mute/0-15
/play [file]
/autoplay [folder]
/stopautoplay
/stop

♻️ Bot
/restart
/help


---

👨‍💻 Developer

Made with ❤️ by Yuvraj (mafiya)
Termux Advanced Automation Project


---

📜 License

MIT License — free to use & modify.


---
