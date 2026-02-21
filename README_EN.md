# sms2tg (RouterOS 7.x) — Cyrillic SMS → Telegram + multipart SMS concatenation + /SMS archive

A MikroTik RouterOS 7.x script that:
- reads incoming SMS from `/tool sms inbox`
- **concatenates multipart SMS (UDH concat)** into a single message
- sends the result to Telegram via Bot API (`sendMessage`)
- **deletes SMS from the modem memory** (keeps inbox clean)
- **archives** processed messages into the router filesystem under **/SMS**

> This repo ships a single `sms2tg.rsc` installer that creates the script and a scheduler.

---

## Features

- ✅ Multipart SMS concatenation (UDH concat):
  - 8-bit reference: `00 03`
  - 16-bit reference: `08 04`
- ✅ Archiving to `/SMS` (single and concatenated messages)
- ✅ On-disk buffering for multipart parts until the message is complete
- ✅ Scheduler every 30 seconds (**created with disabled=yes**)
- ✅ Optional `RESET` command (whitelisted senders)

---

## Requirements

- MikroTik RouterOS **7.x**
- LTE modem with `/tool sms` support
- Internet access to `api.telegram.org`
- Telegram bot token + target `chat_id` (group/channel/chat)

---

## Installation

### 1) Import
WinBox → **Files** → upload `sms2tg.rsc`

Terminal:
```routeros
/import sms2tg.rsc
```

After import you will have:
- `/system script sms2tg` — main script (settings are inside)
- `/system scheduler sms2tg` — runs every 30s (**disabled=yes**)
- `/SMS` folder

> The scheduler is disabled by default on purpose: set token/chat first, then enable it.

---

## Configuration (edit inside the script)

WinBox → **System → Scripts → sms2tg → Source**  
Find the settings block and update values:

```routeros
:local smsNum "+7 (000) 000-00-00";
:local resetFromList "+79990000000,+79990000001";
:local tgToken "PUT_TELEGRAM_BOT_TOKEN_HERE";
:local tgChatId "PUT_TELEGRAM_CHAT_ID_HERE";
:local smsPort "lte1";
```

### What it means
- `smsNum` — “device phone number” shown in Telegram header (cosmetic)
- `resetFromList` — senders allowed to trigger `RESET`
- `tgToken` — Telegram bot token
- `tgChatId` — destination chat_id (group/channel/chat)
- `smsPort` — modem port (e.g. `lte1`)

---

## First test

Run manually:
```routeros
/system script run sms2tg
```

Check logs:
```routeros
/log print where message~"sms2tg:"
```

---

## Enable the Scheduler

WinBox → **System → Scheduler → sms2tg** → set `disabled=no`

Or via terminal:
```routeros
/system scheduler set [find where name="sms2tg"] disabled=no
```

---

## Archiving

All processed messages are written to `/SMS`.

- Single SMS:
  - `SMS/sms_<date>_<time>_from<digits>_id<ID>.txt`

- Concatenated multipart SMS:
  - `SMS/sms_<date>_<time>_from<digits>_ref<REF>.txt`

- Multipart buffer (temporary until complete):
  - `SMS/smsbufc_<fromdigits>_<REF>.txt`

Once the message is successfully assembled and sent, the buffer file is removed.

> If Telegram is unreachable, the multipart buffer may remain and will be sent later on the next successful run.

---

## RESET command (optional)

If an incoming SMS contains `RESET` and the sender is listed in `resetFromList`, the script:
1) sends the message to Telegram
2) reboots the router

---

## How to get `chat_id`

Quick method:
1) Add your bot to the target group/channel (and grant posting rights if needed)
2) Send any message there
3) Call `getUpdates` and look for `chat.id`

Example (replace `TOKEN`):
```routeros
/tool fetch url="https://api.telegram.org/botTOKEN/getUpdates" keep-result=yes
/file print where name~"getUpdates"
```

---

## Troubleshooting

### `Couldn't start task: Please provide IP address or host`
DNS / routing to Telegram API is not working.

Check:
```routeros
/ip dns print
/tool fetch url="https://api.telegram.org" keep-result=no
```

### Multipart SMS is not concatenated
Concatenation works only if the modem provides proper UDH concat headers.  
If the modem exposes parts without UDH, reliable concatenation is not possible.

### Not enough storage space
Archives grow under `/SMS`. If you receive many SMS:
- periodically delete old archive files, or
- store archives on USB / external storage (and adjust paths if needed).

---

## Security

Do not commit real values for:
- `tgToken`
- `tgChatId`
- whitelist numbers

Keep placeholders in the repo and edit the values on the router after import.

---

## License

MIT
