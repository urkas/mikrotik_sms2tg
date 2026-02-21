# sms2tg (RouterOS 7.x) — Cyrillic SMS → Telegram + склейка длинных SMS + архив в /SMS

Скрипт для MikroTik RouterOS 7.x, который:
- Понимает SMS на русском. Никаких ??????????? ??????? ?????.
- **склеивает длинные SMS (multipart / UDH concat)** в одно сообщение
- отправляет сообщение в Telegram через Bot API (`sendMessage`)

> В репозитории один файл `sms2tg.rsc`, который ставит script + scheduler.

---

## Возможности

- ✅ Склейка multipart SMS (UDH concat):
  - 8-bit reference: `00 03`
  - 16-bit reference: `08 04`
- ✅ Архивирование в `/SMS` (одиночные и склеенные)
- ✅ Буферизация частей multipart на диске до полной сборки
- ✅ Scheduler каждые 30 секунд (**создаётся disabled=yes**)
- ✅ Опциональная команда `RESET` (белый список номеров)

---

## Требования

- MikroTik RouterOS **7.x**
- LTE/модем с поддержкой `/tool sms`
- Доступ в интернет к `api.telegram.org`
- Telegram Bot Token + Chat ID (канал/группа/чат)

---

## Установка

### 1) Импорт
WinBox → **Files** → загрузить `sms2tg.rsc`

Терминал:
```routeros
/import sms2tg.rsc

```

После импорта создаются:
- `/system script sms2tg` — основной скрипт (с настройками внутри)
- `/system scheduler sms2tg` — каждые 30 секунд (**disabled=yes**)
- папка `/SMS`

> Scheduler создаётся выключенным специально: сначала настроишь токен/чат, потом включишь.

---

## Настройка (правится прямо в скрипте)

WinBox → **System → Scripts → sms2tg → Source**  
Найди блок настроек и поменяй значения:

```routeros
:local smsNum "PUT_MODEM_PHONE_NUM_HERE";
:local resetFromList "PUT_YOUR_PHONE_NUM_HERE";
:local tgToken "PUT_TELEGRAM_BOT_TOKEN_HERE";
:local tgChatId "PUT_TELEGRAM_CHAT_ID_HERE";
:local smsPort "lte1";
```
### Что означает

- `smsNum` — “номер устройства” для шапки в Telegram (косметика) например "+7 (000) 000-00-00"
- `resetFromList` — номера, которым разрешено прислать `RESET`, например "+79990000000,+79990000001"
- `tgToken` — токен Telegram‑бота
- `tgChatId` — chat_id (канал/группа/чат)
- `smsPort` — порт модема (например `lte1`)

---

## Первый тест

Запусти вручную:

```routeros
/system script run sms2tg
```

## Включение Scheduler

WinBox → **System → Scheduler → sms2tg** → `disabled=no`

или терминал:

```routeros
/system scheduler set [find where name="sms2tg"] disabled=no
```

---

## Архивирование

Все обработанные сообщения пишутся в `/SMS`.

- Одиночные SMS:
  - `SMS/sms_<date>_<time>_from<digits>_id<ID>.txt`

- Склеенные (multipart):
  - `SMS/sms_<date>_<time>_from<digits>_ref<REF>.txt`

- Буфер частей длинной SMS (временный файл до сборки):
  - `SMS/smsbufc_<fromdigits>_<REF>.txt`

После успешной сборки и отправки буфер удаляется.

> Если Telegram недоступен — буфер multipart может остаться и будет отправлен позже при следующем успешном запуске.

---

## Команда RESET (опционально)

Если SMS содержит `RESET` и номер отправителя есть в `resetFromList`, скрипт:
1) отправит сообщение в Telegram
2) выполнит reboot

