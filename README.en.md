# JiaoGe 🍌

[中文](README.md) | **English**

A macOS desktop banana pet that breathes, blinks and waves — and happens to be useful.

**What it's actually good for:**

| Feature | What it does |
|---|---|
| 📷 **Screenshot OCR** `⌃⌥O` | Select part of the screen and get the text. 13 languages, on-device, no network. Tables and multi-column layouts are reconstructed |
| 🌐 **Screenshot translate** `⌃⌥T` | Select part of the screen and get a translation. Long text is chunked automatically; the bubble stays on screen until you click elsewhere |
| 📋 **Clipboard history** `⌃⌥V` | Remembers text and images, searchable, pinnable, one key to put it back |
| 💬 **Chat with an LLM** | DeepSeek / Qwen / Kimi / Zhipu / OpenAI / local Ollama. History survives restarts |
| 🍅 **Pomodoro + break reminders** | Countdown in the menu bar; it speaks up when you sit too long, forget water, or run low on battery |
| 🏆 **Progression** | Earn XP by clicking, chatting and finishing pomodoros; climb from Iron to Challenger with a crown that changes as you rank up |

> **Platform**: macOS 12+ only, **Apple Silicon (arm64)** — the released build won't run on Intel Macs. Not available on Windows/Linux.
> **Install**: grab the zip from [Releases](https://github.com/jackLin5999/jiaoge-pet/releases) — see [Install & first launch](#install--first-launch) below; developers can just run `./run.sh`.

---

## Install & first launch

### 1. Download

Get **`JiaoGe-x.x.x.zip`** from [Releases](https://github.com/jackLin5999/jiaoge-pet/releases/latest) (the newest one).

> ⚠️ Don't download `Source code (zip)` — that's the source, there's no runnable app inside.

### 2. Move it to Applications

Unzip and drag **JiaoGe.app** into your Applications folder.

### 3. First launch (macOS will block it once)

Double-clicking shows:

> **"Apple could not verify 'JiaoGe.app' is free of malware that may harm your Mac or compromise your privacy."**

This is **expected** — it's an unsigned, un-notarized personal project, not malware. Click **Done** — never **Move to Trash**.

Then either:

**Option A: System Settings (recommended)**
1. Open **System Settings → Privacy & Security**
2. Scroll down; you'll see *"JiaoGe.app was blocked…"* → click **Open Anyway**
3. Authenticate with Touch ID / password
4. Double-click the app again and confirm **Open**

**Option B: one terminal command**
```bash
xattr -dr com.apple.quarantine /Applications/JiaoGe.app
```
After that it opens normally with no prompt.

> On recent macOS versions, right-click → Open may not offer an "Open" button; use the System Settings path.

### 4. Grant screen recording (needed for screenshots)

The first time you press `⌃⌥O` or `⌃⌥T`, macOS asks for screen recording permission — allow it.
**You must quit and reopen the app** before the permission takes effect.

If screenshots later fail, check System Settings → Privacy & Security → Screen Recording and make sure JiaoGe is on.

### 5. Connect an LLM (needed for chat and translation)

Click the 🍌 in the menu bar → **Model settings…**

| Field | Value |
|---|---|
| Provider | DeepSeek |
| API base URL | `https://api.deepseek.com/v1` |
| Model | `deepseek-flash` |
| API key | your own key |

Use **Test connection** before saving.

> **Screenshot OCR works without any API key** — only translation and chat need one.

### Troubleshooting

Common issues (won't open, nothing appears, black screenshots, API errors, hotkeys not working) are covered in
[INSTALL.md](INSTALL.md) (Chinese).

Still stuck? Run the self-test and paste the output into an [issue](https://github.com/jackLin5999/jiaoge-pet/issues):

```bash
/Applications/JiaoGe.app/Contents/MacOS/JiaoGe --self-test
```

## Screenshot OCR / translation

- **`⌃⌥O`** — select a region (the system selection UI, Esc to cancel), text is recognized locally and copied to the clipboard
- **`⌃⌥T`** — same selection, then the text is sent to your LLM for translation; the result goes to the clipboard and is shown in a bubble

Recognition runs on-device via Apple's Vision framework, **no network involved**; only the translation step calls the API.

### Two translation modes

| Mode | How it works | Good for |
|---|---|---|
| Local OCR + text translation (default) | Vision extracts text on-device, then the text is sent to the model | Works with text-only models, cheaper, faster |
| Send the image directly (vision model) | The whole screenshot goes to the model, which reads and translates it | Tables, complex layouts and handwriting; more expensive, and the image leaves your machine |

Enable "this model can see images" in Model settings to use the second mode. For DeepSeek use `deepseek-flash`.

Without a configured model, the "Screenshot translate" menu item is labeled *"connect a model first"* and pressing `⌃⌥T`
offers to open the settings.

**The translation bubble stays on screen** until you click elsewhere. Dragging the pet moves it along instead of dismissing it.

### Target language

Menu: **Translation target language** (right under Screenshot translate). The default is *Auto* — Chinese source becomes
English, anything else becomes Chinese. You can also pin it to Chinese / English / Japanese / Korean / French / German /
Spanish / Russian; both translation modes respect it.

### Supported languages

Recognized in practice: Chinese, Japanese, Korean, English, French, German, Spanish, Portuguese, Vietnamese, Russian,
Arabic, Thai, Hindi. Recognition is fully local and usually takes one or two hundred milliseconds.

A few accented Latin languages may lose diacritics (Spanish ñ, Vietnamese tones), but the words themselves are correct.

### Layout reconstruction

- Multiple text blocks on the same line are joined with `  |  `, so **tables come out as table rows**
- When two columns are detected, text is read **column by column**, not interleaved
- Large vertical gaps are preserved as blank lines (paragraph breaks)

Long text is translated in chunks; if a chunk hits the token limit (`finish_reason == length`) it is split in half and
retried, so long screenshots don't lose their tail.

## Clipboard history

Polls the clipboard every 0.5 s and keeps the last 20 **text and image** entries.

- **Right-click the pet**, or press **`⌃⌥V`** anywhere: a list appears above the pet. Type to search, press 1–9 to pick,
  ↑↓ then Enter also works. Esc or a click outside closes it. Picking puts the item back on the clipboard and returns
  focus to your previous app — just press ⌘V
- Click the **📌** on the right of a row to pin it; pinned items are never evicted
- The 🍌 menu lists the 5 most recent items at the top

(⌥⌘V is "paste and match style" in many editors, hence ⌃⌥V.)

Images (screenshots, copied web images, image files from Finder) are stored as PNG with thumbnails and dimensions in the
panel. They're named by content hash, so duplicates aren't stored twice; files over 40 MB are skipped. Image files are
deleted when the entry is evicted or the history is cleared.

Single-token strings that look like secrets (`sk-`, `AKIA`, `ghp_` prefixes) are not recorded.

History lives in `~/Library/Application Support/JiaoGe/clipboard.json`, images in `clip/` next to it — readable only by your user.

## Chat

Menu → **Open chat box** pops up an input field above the pet. Type, press Enter, and the reply appears in the bubble
(multi-line supported). Esc closes it (right-click is taken by the clipboard).

The endpoint follows OpenAI's `/chat/completions` format, so all of these work:

| Provider | Base URL | Model example |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-flash` (vision-capable) |
| Qwen (DashScope) | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| Kimi (Moonshot) | `https://api.moonshot.cn/v1` | `moonshot-v1-8k` |
| Zhipu GLM | `https://open.bigmodel.cn/api/paas/v4` | `glm-4-flash` |
| SiliconFlow | `https://api.siliconflow.cn/v1` | `deepseek-ai/DeepSeek-V3` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| Ollama (local) | `http://localhost:11434/v1` | `qwen2.5` |

Anything else compatible: pick "Custom" and fill in the fields. Config and key are stored in
`~/Library/Application Support/JiaoGe/config.json` with mode 600.

Chat history is saved locally (last 50 messages); the last 12 are sent as context with each request.
Menu → **Clear chat memory** wipes it.

## Pomodoro, sitting reminders and proactive care

**Pomodoro**: menu → Pomodoro → Start focus. The remaining time shows in the menu bar (🍌 24:59). Focus ends and the
break starts automatically, then you get a reminder when the break ends. Default 25 / 5 minutes, adjustable to 15 / 25 / 50
and 5 / 10.

It also checks in on you (all configurable or disableable in the menu):

- **Sitting reminder**: every 45 minutes by default (30 / 60 or off)
- **Water**: hourly between 9:00 and 21:00
- **Lunch**: once at noon
- **90 minutes of continuous computer use**: suggests a break (based on keyboard/mouse idle time, so it won't bother you when away)
- **Battery below 20%**: charging reminder
- **CPU pegged** (over 85% for 30 s): it shivers and says it's hot
- **Network up/down**: mention
- **Greeting**: by time of day at launch; more likely to doze off after 22:00

**Daily summary** at 21:30, e.g.

> Today: poked 42 times, 3 pomodoros / 75 minutes, 12 items copied, chatted 5 times. Well done, get some rest.

Silent if there was no activity. Menu → **Today's summary** shows it on demand.

**Sound effects**: a click tick, a chord on level-up, a chime when a pomodoro ends, a pop when a reply arrives — all
toggleable in the menu.

## Ranks, affinity and crowns

The menu shows:

- "Poked N times today" (resets at midnight)
- "N pomodoros today · M minutes"
- "Affinity Lv.N rank · X/Y · K-day streak · day D of knowing each other" (click it and the pet says it out loud)

**XP**: click +1, successful chat +5, completed pomodoro +20 — **no daily caps**; the first interaction of the day gives
+10 and more with a longer streak (capped at +50).

**Ranks** follow League of Legends: Iron / Bronze / Silver / Gold / Platinum / Emerald / Diamond, each with divisions IV–I
(32 levels total). At Lv.33 you enter **Master**, and from there it's points — **2 XP = 1 point**:

| Points | Rank |
|---|---|
| 0 – 799 | Master |
| 800 – 1199 | Grandmaster |
| 1200 – 1999 | Challenger |
| 2000+ | God (hidden tier) |

Each level costs 13, 26, 39… XP. At 150 XP/day: Silver around day 7, Emerald day 26, Master day 46, Grandmaster day 56,
Challenger day 62 (about two months), God around day 72 — and it keeps counting after that.

**Crowns**: every rank has its own crown, and **each division looks different** (progressively lit gems from IV to I), so
the crown changes on every level-up. Assets live in `Resources/crowns/`; preview in `docs/crowns-on-pet.png`.

## How to play with it

| Action | Reaction |
|---|---|
| Left click | Squash and bounce, wave, hearts, a line; **different lines per body part** (head, eyes, mouth, arms, feet, belly — poking an eye makes it blink) |
| Rapid clicks | Shows "combo ×N"; at 4 it widens its eyes, at 7 it goes ×× eyes and shakes its head; lines escalate too |
| Drag | Picks it up (body stretches), it stays where you drop it |
| Right click | Open / close the clipboard panel |
| **⌥ + right click** | Open the full menu (fallback if the menu bar icon is hidden) |
| Menu bar 🍌 | Full menu; shows the pomodoro countdown while running |

The combo counter resets 2.2 s after you stop. Four sizes: small / medium / large / huge, remembered across launches.

When idle it keeps living: breathing (~0.3 s), blinking every 2–5 s, a random action every 6–13 s (hop, look around,
stretch, yawn, tilt its head, shiver, doze off), eyes following your cursor, and click-through when the pointer isn't over it.

## Launch at login

Menu → **Launch at login** (uses `SMAppService`, requires macOS 13+).

## Run from source

```bash
./run.sh        # build and launch
./build.sh      # build only, output in build/JiaoGe.app
```

Needs Command Line Tools (`xcode-select --install`); full Xcode isn't required.
No Dock icon — look for 🍌 in the menu bar.

## Developers

How the character is drawn, the code-signing / screen-recording relationship, the multi-pass OCR strategy and the
self-test commands are documented in [docs/DEVELOPING.md](docs/DEVELOPING.md) (Chinese).

## License

[MIT](LICENSE)
