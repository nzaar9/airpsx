
## Worked examples

All examples assume `AIRPSX=http://192.168.1.50:1214`.

### Chunked, resumable upload

```sh
# 1. start (or resume) a session; the answer contains "id" and "received"
curl -s -X POST $AIRPSX/api/fs/upload-session/init \
  -H 'Content-Type: application/json' \
  -d '{"path":"/data/homebrew/game.pkg","size":1073741824}'

# 2. send chunks starting at "received"; every answer carries the new offset
curl -s -X POST "$AIRPSX/api/fs/upload-session/chunk?id=<id>&offset=0" --data-binary @chunk0.bin

# 3. after a dropped connection ask where to continue
curl -s "$AIRPSX/api/fs/upload-session/status?id=<id>"
```

Pausing is simply not sending the next chunk; `cancel` removes the partial file. The final chunk renames `<path>.part` to `<path>`. Limit: files below 2 GB.

### Task triggers

A task runs from its `script` (RuleScript or Lua). `triggerType` decides when:

| `triggerType` | `triggerValue` | Runs |
|---|---|---|
| `cron` (default) | - | every `frequency` seconds |
| `boot` | - | once, after AirPSX starts |
| `game_launch` | optional title ID | when a game starts (checked every 60 s) |
| `game_close` | optional title ID | when a game exits (checked every 60 s) |
| `temp_above` | temperature in °C | once when the CPU reaches it, again after it cools below |

```sh
curl -s -X POST $AIRPSX/api/task/update -H 'Content-Type: application/json' \
  -d '{"id":1,"triggerType":"game_launch","triggerValue":"PPSA01234"}'
```

Event scripts receive the event data (`titleID`, `temperature`) as extra variables.

### Alerts and event webhooks

```sh
# POST a message when the CPU reaches 85 °C (at most once per 10 minutes)
curl -s -X POST $AIRPSX/api/stats/alert -H 'Content-Type: application/json' \
  -d '{"temperature":85,"webhook":"https://discord.com/api/webhooks/..."}'

# send events to Home Assistant / n8n
curl -s -X POST $AIRPSX/api/stats/alert -H 'Content-Type: application/json' \
  -d '{"eventWebhook":"http://homeassistant.local:8123/api/webhook/airpsx","events":"game_launch,game_close"}'
```

Alert webhooks receive `{"content": "...", "text": "..."}` (Discord and Slack compatible). Event webhooks receive `{"event": "game_launch", "time": "...", "data": {"titleID": "..."}}`. Events: `game_launch`, `game_close`, `backup_done`, `backup_failed`.

### Scheduled save backups

```sh
curl -s -X POST $AIRPSX/api/save/backups/config -H 'Content-Type: application/json' \
  -d '{"enabled":true,"intervalHours":24,"destination":"/mnt/usb0/airpsx","keep":7}'
curl -s -X POST $AIRPSX/api/save/backups/run          # run now
curl -s $AIRPSX/api/save/backups/list
curl -s -X POST $AIRPSX/api/save/backups/restore -H 'Content-Type: application/json' -d '{"id":3}'
```

Backups are tar files written to any mounted path (USB drive or a mounted network share). Only the newest `keep` are retained. Restore writes only below `<profile>/savedata*` and is refused while a game is running.

### Install queue

```sh
curl -s -X POST $AIRPSX/api/package/queue/add -H 'Content-Type: application/json' \
  -d '{"source":"/mnt/usb0/packages"}'      # a folder, a .pkg, or an http(s) URL
curl -s $AIRPSX/api/package/queue/list
```

Entries are handed to the system installer one at a time, 5 seconds apart. `submitted` means the console accepted the package; installation progress is shown by the console itself.

### Maintenance mode

`POST /api/system/maintenance {"enabled": true}` stops AirPSX from starting anything by itself (tasks, scheduled backups, queued installs and decrypt jobs) until it is switched off again. Manual API calls keep working.

### SELF decrypt jobs

The queue (`/api/decrypt/*`) persists jobs and survives crashes, but no decryption backend ships with AirPSX: jobs fail with "No SELF decrypt backend is installed". See `src/airpsx/decrypt/SelfDecryptBackend.hx` to plug one in.
