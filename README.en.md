# JiaoGe 🍌

[中文](README.md) | **English**

A macOS desktop banana pet that breathes, blinks and waves — and happens to be useful.

**What it's actually good for:**

| Feature | What it does |
|---|---|
| 📷 **Screenshot** `⌃⌥S` | Select part of the screen, then choose **OCR**, **Translate** or **Ask**. OCR is on-device: 13 languages, tables and multi-column layouts preserved |
| 📋 **Clipboard history** `⌃⌥V` | Remembers text and images, searchable, pinnable, one key to put it back |
| 💬 **Chat with an LLM** | DeepSeek / Qwen / Kimi / Zhipu / OpenAI / local Ollama. History survives restarts |
| 🍅 **Pomodoro + break reminders** | Countdown in the menu bar; it speaks up when you sit too long, forget water, or run low on battery |
| 🏆 **Progression** | Earn XP by clicking, chatting and finishing pomodoros; climb from Iron to Challenger with a crown that changes as you rank up |
| 🎭 **Appearance** | Swap the banana for an animated pet from [Petdex](https://petdex.dev); every feature and reaction still works |

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

The first time you press `⌃⌥S`, macOS asks for screen recording permission — allow it.
**You must quit and reopen the app** before the permission takes effect.

If screenshots later fail, check System Settings → Privacy & Security → Screen Recording and make sure JiaoGe is on.

### 5. Connect an LLM (needed for chat and translation)

Click the 🍌 in the menu bar → **Model settings…**

> **Can't find the 🍌 in the menu bar?** Hold **⌥** and **right-click the pet** — the full menu pops up there.
> macOS hides status items when the menu bar runs out of room; this is the fallback.
> On first launch without a configured model, the settings window also opens by itself.

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

## Screenshot: OCR, translate, ask

Press **`⌃⌥S`** and select a region (the system selection UI, Esc to cancel). A small toolbar appears next to the pointer:

- **1 OCR** — text is recognized locally and copied to the clipboard (and kept in clipboard history)
- **2 Translate** — sent to your LLM; the translation goes to the clipboard and appears in the bubble
- **3 Ask** — opens the chat box so you can ask about what you selected, with follow-ups until you close it

Use the number keys or click. The button under the pointer is highlighted and **Return does the highlighted one**
(your last choice when the pointer isn't over a button); Esc or clicking elsewhere cancels, and it cancels by itself after 10 seconds. The toolbar doesn't take focus, so your cursor stays in your app.

The shortcuts can be changed under Settings → *Shortcuts…*: click a button, then press the new combination (it must include ⌃, ⌥ or ⌘).

Recognition runs on-device via Apple's Vision framework, **no network involved**; only Translate and Ask call the API, so configure a model first.

**What Ask sends**: with "this model can see images" enabled, the whole screenshot; otherwise the locally recognized text (so images without text can't be asked about). Screenshots are first scaled down on your Mac to 1600 px on the long side and sent as whichever of PNG or JPEG is smaller, which saves bandwidth and tokens. Neither is saved to chat history, and each follow-up sends it again.

**Long results**: the bubble shows the first ~120 characters — **click the bubble** to open a scrollable
full-text card where you can select and copy everything. The menu also has *View last result*.
Translation results work the same way.

### Two translation modes

| Mode | How it works | Good for |
|---|---|---|
| Local OCR + text translation | Vision extracts text on-device, then the text is sent to the model | Works with text-only models, cheaper, faster |
| Send the image directly (default, vision model) | The whole screenshot goes to the model, which reads and translates it | Tables, complex layouts and handwriting; more expensive, and the image leaves your machine |

Sending the image is the default — most current models can see images (DeepSeek's `deepseek-flash` can). If your model is text-only, untick "this model can see images" in Model settings to use local OCR instead.

Without a configured model, Translate and Ask are greyed out on the toolbar; choosing one tells you so and opens the settings.

**Translations stream in** as they're generated. While translating, **click the bubble to stop**; whatever is done so far is still copied.

**The translation bubble stays on screen** until you click elsewhere. Dragging the pet moves it along instead of dismissing it.

### Target language

Menu → Settings → **Translation target language**. The default is *Auto* — Chinese source becomes
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

Long text is translated in chunks, up to 3 at a time, then put back together in order; if the API rate-limits, it falls
back to one chunk at a time. If a chunk hits the token limit (`finish_reason == length`) it is split in half and
retried, so long screenshots don't lose their tail.

## Clipboard history

Polls the clipboard every 0.5 s and keeps the last 20 **text and image** entries.

- **Right-click the pet**, or press **`⌃⌥V`** anywhere (changeable under Settings → *Shortcuts…*): a list appears above the pet. Type to search, press 1–9 to pick,
  ↑↓ then Enter also works. Esc or a click outside closes it. Picking puts the item back on the clipboard and returns
  focus to your previous app — just press ⌘V
- Click the **📌** on the right of a row to pin it; pinned items are never evicted
- 🍌 menu → Clipboard lists the 10 most recent items

(⌥⌘V is "paste and match style" in many editors, hence ⌃⌥V.)

Images (screenshots, copied web images, image files from Finder) are stored as PNG with thumbnails and dimensions in the
panel. They're named by content hash, so duplicates aren't stored twice; files over 40 MB are skipped. Image files are
deleted when the entry is evicted or the history is cleared.

These are not recorded:

- Anything copied from a password manager (the standard "concealed" pasteboard markers are respected, and Apple Passwords, Keychain Access, 1Password, Bitwarden and others are skipped outright)
- Single-token strings that look like secrets (`sk-`, `AKIA`, `ghp_` prefixes)
- Apps you exclude: while in that app, use the 🍌 menu → Clipboard → "不记录「…」" (don't record)

Everything else stays in the local `clipboard.json` (mode 600, not encrypted). Exclusions only affect future copies; use *Clear history* for what's already there.

History lives in `~/Library/Application Support/JiaoGe/clipboard.json`, images in `clip/` next to it — readable only by your user.

## Chat

Menu → **Open chat box** pops up an input field above the pet. Type, press Enter, and the reply appears as it's generated, in a bubble above the input
(multi-line supported). The input stays open so you can keep asking; press Esc, click elsewhere or press Enter on an empty
line to close it (right-click is taken by the clipboard).

If a reply is too long for the bubble, only the start is shown and already-shown text never scrolls away; click the bubble
for the full text. Sending a new message interrupts an unfinished reply.

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
Menu → Settings → **Clear chat memory** wipes it.

## Pomodoro, sitting reminders and proactive care

**Pomodoro**: menu → Pomodoro → Start focus. The remaining time shows in the menu bar (🍌 24:59). When focus ends,
a small card asks whether to start the break or skip it — the next segment never starts on its own; when the break
ends it asks the same about focusing again. Default 25 / 5 minutes, adjustable to 15 / 25 / 50
and 5 / 10.

It also checks in on you (all configurable or disableable in the menu):

- **Sitting reminder**: every 45 minutes by default (30 / 60 or off). Being away for 5+ minutes (or locking the screen) counts as a break, so the timer restarts when you're back
- **Water**: hourly between 9:00 and 21:00
- **Lunch**: once at noon
- **90 minutes of continuous computer use**: suggests a break (based on keyboard/mouse idle time, so it won't bother you when away)
- **Battery below 20%**: charging reminder
- **CPU pegged** (over 85% for 30 s): it shivers and says it's hot
- **Network up/down**: mention
- **Greeting**: by time of day at launch; more likely to doze off after 22:00

**It won't interrupt focus or full screen**: during a focus session or while any app is full screen (coding, video, slides),
reminders are held and said together afterwards. Things that go stale, like CPU and network notices, are dropped. The
pomodoro card still appears on time. To keep reminders on in full screen, turn off Settings → *Pause reminders in full
screen*. Sharing your screen in a meeting app without going full screen can't be detected, so reminders still appear.

**It won't talk to an empty room**: when the screen is locked, the display is asleep, or the keyboard and mouse have been
idle for 5 minutes, reminders are held the same way and said together when you're back.

**Daily summary** at 21:30, e.g.

> Today: poked 42 times, 3 pomodoros / 75 minutes, 12 items copied, chatted 5 times. Well done, get some rest.

Silent if there was no activity. Menu → Affinity → **Today's summary** shows it on demand.

**Sound effects**: a click tick, a chord on level-up, a chime when a pomodoro ends, a pop when a reply arrives — all
toggleable in the menu.

## Ranks, affinity and crowns

The top level of the menu shows "Affinity Lv.N rank · X/Y". Open it to see:

- "K-day streak · day D of knowing each other" (click it and the pet says it out loud)
- "Poked N times today" (resets at midnight)
- "N pomodoros today · M minutes"

**XP**: click +1, tickle +1, successful chat +5, completed pomodoro +20 — **no daily caps**; the first interaction of the day gives
+10 and more with a longer streak (capped at +50).

**Ranks** follow League of Legends: Iron / Bronze / Silver / Gold / Platinum / Emerald / Diamond, each with divisions IV–I
(32 levels total). At Lv.33 you enter **Master**, and from there it's points — **1 XP = 1 point**:

| Points | Rank |
|---|---|
| 0 – 799 | Master |
| 800 – 1199 | Grandmaster |
| 1200 – 1999 | Challenger |
| 2000+ | God (hidden tier) |

Early levels are quick: before Emerald each level costs 4, 9, 13, 17… XP; from Emerald on, 163–208 per level.
At 150 XP/day: Silver around day 3, Emerald day 9, Master day 19, Grandmaster day 24, Challenger day 27,
God around day 32 (about a month) — and it keeps counting after that.

**Crowns**: every rank has its own crown, and **each division looks different** (progressively lit gems from IV to I), so
the crown changes on every level-up. Assets live in `Resources/crowns/`; preview in `docs/crowns-on-pet.png`.

Don't like the crown? Untick **显示段位皇冠** (Show rank crown) under 🍌 menu → **外观** (Appearance); ranks and XP keep counting.

## How to play with it

| Action | Reaction |
|---|---|
| Left click | Squash and bounce, wave, hearts, a line; **different lines per body part** (head, eyes, mouth, arms, feet, belly — poking an eye makes it blink) |
| Rapid clicks | Shows "combo ×N"; at 4 it widens its eyes, at 7 it goes ×× eyes and shakes its head; lines escalate too |
| Drag | Picks it up (body stretches), it stays where you drop it |
| Rest the pointer on it | A small perk-up and slightly wider eyes; squints happily if you stay (no speech; passing over doesn't count) |
| Rub quickly back and forth on it | **Tickle**: it giggles, wiggles and sends hearts, with a new line every second that gets more frantic until it's laughed out; +1 XP each time, trackpad rubbing works too |
| Right click | Open / close the clipboard panel |
| **⌥ + right click** | Open the full menu (fallback if the menu bar icon is hidden) |
| Menu bar 🍌 | Full menu; shows the pomodoro countdown while running |

The combo counter resets 2.2 s after you stop. Four sizes: small / medium / large / huge, remembered across launches.

When idle it keeps living: breathing (~3 s), blinking every 2–5 s, a random action every 6–13 s (hop, look around,
stretch, yawn, tilt its head, shiver, doze off), eyes following your cursor, and click-through when the pointer isn't over it.

It's light on battery: it only redraws when something visibly changes (about 2% CPU when idle) and stops drawing
entirely while the screen is locked or the display is asleep.

## Appearance: import a Petdex pet

JiaoGe is a banana by default, but you can swap it for an animated pet from [petdex.dev](https://petdex.dev).
Only the look changes — screenshots, clipboard, chat, pomodoro and everything else work as before.

1. 🍌 menu → **外观** (Appearance) → **去 petdex.dev 挑选** (Browse petdex.dev), pick a pet and download its zip
2. 🍌 menu → **外观** → **导入 Petdex 宠物…** (Import Petdex pet), choose the zip (an unzipped folder works too)
3. The new look appears right away

Every pet you've imported is listed under **外观**; click a name to switch. **蕉哥（原版）** brings the banana back,
and **删除「name」** removes an imported pet. Both Petdex formats are supported (8×9 and the v2 8×11 grid).
Imported pets are copied to `~/Library/Application Support/JiaoGe/skins/`, so you can delete the download afterwards.

How the banana's reactions map onto a pet:

| Banana | Imported pet |
|---|---|
| Click | Waves, hearts |
| 4 rapid clicks | Jumps with a "!" above its head |
| 7 rapid clicks | Gets dizzy, stars circling its head |
| Drag | Runs in the direction you drag |
| Waiting for the LLM, translating | Thinking animation |
| Focus session running | Working animation |
| A pomodoro phase ended, waiting for your choice | Waiting animation |
| Idle hop / yawn / doze | Matching animations; floating z's when dozing |
| Tickle | Bounces around; switches to the "failed" row once it's laughed out |
| Breathing, head tilt, shiver, squash and bounce | Same as before |
| Eyes follow the cursor | Leans slightly toward the cursor |

- Your rank crown still sits on its head
- A pet's eyes and mouth can't be located, so it has different lines for head, arms, feet and belly, and generic lines for the face
- The window is sized for a tall, thin banana, so wide pets look a bit smaller — use Settings → Size to enlarge
- Pets are drawn differently, so some fit these reactions better than others

> **Copyright**: most Petdex pets are user-submitted fan art; rights belong to their creators and the characters' owners.
> JiaoGe doesn't ship or distribute any pets — it only lets you import one. Keep them for personal use and don't redistribute them.

## Launch at login

Menu → Settings → **Launch at login** (uses `SMAppService`, requires macOS 13+).

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
