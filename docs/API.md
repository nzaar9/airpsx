# AirPSX HTTP API

Generated from `src/hx/well/route/ApiRoute.hx` by `tools/gen_api_docs.py`; edit `tools/api_descriptions.json` or `tools/api_extra.md`, not this file. All paths are relative to `http://<console-ip>:1214`.

## Conventions

- Requests and responses are JSON unless noted. Send `Content-Type: application/json` with POST bodies.
- Handler errors are usually `200` with `{"error": "..."}` or `{"success": false, "message": "..."}`; validation failures return `422`; unknown routes fall back to the web UI.
- **console only** routes exist only in console builds (the Linux host build used for development omits them).
- **stream** routes read the request body themselves (uploads) and accept very large bodies.
- There is no authentication. Anyone who can reach port 1214 can use every endpoint, so keep it on a trusted network.

## Package install

| Method | Path | Flags | Description |
|---|---|---|---|
| GET | `/api/package/{file}.crc` |  | Always answers 404 (the console probes for a CRC file during installs). |
| POST | `/api/package/upload/init` |  | Start a PKG install session that streams a package from the browser to the console installer. Query: `size`, `titleId`, `title`, `iconPath`. Returns a `sessionKey`. |
| POST | `/api/package/upload/cancel` |  | Cancel a streaming install session: `{sessionKey}`. |
| POST | `/api/package/upload/list` |  | List the chunks received so far for a session. Query: `sessionKey`. |
| POST | `/api/package/upload` | stream | Upload one chunk of a streaming install. Query: `sessionKey`, `chunkKey`. Raw body. |
| GET | `/api/package/{sessionKey}.pkg` |  | Console-only: the system installer pulls the streamed package from here. Do not call from the web. |
| POST | `/api/package/install` |  | Install a package from a URL or an existing file path: `{path}`. Fire and forget. |
| POST | `/api/package/preview` |  | Read a local PS4-format PKG header: content ID, title ID, title, version, icon. `{path}`. |
| POST | `/api/package/queue/add` |  | Queue PKG installs from an http(s) URL, a local `.pkg`, or a folder of `.pkg` files: `{source}`. |
| GET | `/api/package/queue/list` |  | The install queue with per-entry status. |
| POST | `/api/package/queue/cancel` |  | Cancel a pending queue entry, or re-queue a failed/cancelled one with `retry: true`: `{id, retry?}`. |

## File system

| Method | Path | Flags | Description |
|---|---|---|---|
| POST | `/api/fs/list` |  | List a directory: `{path}`. Returns name, type, size and timestamps per entry. |
| POST | `/api/fs/payload` |  | Send an ELF file to the console's ELF loader on a local port (9020, 9021, 9022 or 9090) after checking its ELF header: `{path}`. |
| GET | `/api/fs/download/{encodedPath}` |  | Download files or folders. `encodedPath` is the Base64 of the comma-separated paths; folders stream as a tar. |
| POST | `/api/fs/upload/{path}` | stream | Single-request upload (multipart/form-data as sent by the web UI, or the raw bytes). For large files use the upload-session endpoints. |
| POST | `/api/fs/rename` |  | Rename in place: `{path, name}` (`name` is a bare file name). |
| POST | `/api/fs/search` |  | Case-insensitive name search, bounded by result count and time: `{path, query, limit?}`. |
| POST | `/api/fs/batch` |  | Copy, move or delete several items as a background job: `{op, paths, destination?}`. Returns `{job}`. |
| POST | `/api/fs/archive` |  | Zip or unzip as a background job: `{action:"zip", paths, output}` or `{action:"unzip", path, destination}`. |
| GET | `/api/fs/job` |  | Status of a background job. Query: `id`. |
| POST | `/api/fs/text` |  | Read a text file up to 1 MB, or save it when `content` is given: `{path, content?}`. |
| POST | `/api/fs/hex` |  | Hex viewer: up to 4096 bytes as hex plus ASCII: `{path, offset?, length?}`. |
| POST | `/api/fs/upload-session/init` |  | Start or resume a chunked upload: `{path, size, overwrite?}`. Returns the session with its `received` offset. |
| POST | `/api/fs/upload-session/chunk` | stream | Upload one chunk at an offset (raw body). Query: `id`, `offset`. A wrong offset answers with the offset to resume from. |
| GET | `/api/fs/upload-session/status` |  | State of one session (`id`), or all unfinished sessions without it. |
| POST | `/api/fs/upload-session/cancel` |  | Discard a session and its partial file: `{id}`. |
| POST | `/api/fs/temp/file` | stream | Upload a file into the temporary folder; returns `{path}`. |
| GET | `/api/fs/stream/{path}` |  | Stream a file; honors HTTP `Range` requests (used for media playback). |

## System & processes

| Method | Path | Flags | Description |
|---|---|---|---|
| GET | `/api/system/status` | console only | CPU frequency and temperatures, CPU mode, and the running application. |
| GET | `/api/system/info` | console only | Static system information: model, serial, SDK/firmware versions, kernel boot time. |
| GET | `/api/system/stats` | console only | Logged thermal samples (last 1000, one per minute) with title names. |
| GET | `/api/profile/list` | console only | User profiles on the console. |
| GET | `/api/profile/image/{profileId}` | console only | Profile avatar image. |
| GET | `/api/title/image/{titleId}` | console only | Title icon image. |
| GET | `/api/storage/info` | console only | Mounted storage devices with used/total bytes. |
| GET | `/api/process/list` | console only | Process list. Adds `uptime` (seconds, from the monotonic clock) and a non-empty `emul`. |
| POST | `/api/process/kill` | console only | Send SIGTERM (or SIGKILL with `force`) to a process: `{pid, force?}`. Refuses pid <= 1 and AirPSX itself. |
| POST | `/api/system/maintenance` |  | Pause automatic work (tasks, scheduled backups, install and decrypt queues): `{enabled?}`. |

## Applications, media & saves

| Method | Path | Flags | Description |
|---|---|---|---|
| GET | `/api/media/list` | console only | Screenshots and video clips. |
| GET | `/api/media/thumbnails/{path}` | console only | Thumbnail of a media file. |
| GET | `/api/media/{path}` | console only | Stream a media file. |
| GET | `/api/app/list` | console only | Installed applications. |
| POST | `/api/app/uninstall/{titleId}` | console only | Uninstall a title (refused while it is running). |
| GET | `/api/app/run/{titleId}` | console only | Launch a title. |
| GET | `/api/save/backup/{profileId?}` | console only | Download a tar of save data for one profile or all profiles. |
| POST | `/api/save/backups/config` | console only | Scheduled backup settings: `{enabled?, intervalHours?, destination?, keep?, profileId?}`; no fields returns the config. |
| POST | `/api/save/backups/run` | console only | Start a backup now. |
| GET | `/api/save/backups/list` | console only | Backups with status. |
| POST | `/api/save/backups/restore` | console only | Restore a backup into the user home (refused while a game is running): `{id, profileId?}`. |
| POST | `/api/save/backups/delete` | console only | Delete a backup file and its record: `{id}`. |

## Tasks & scripts

| Method | Path | Flags | Description |
|---|---|---|---|
| POST | `/api/task/create` |  | Create a task: `{name, type?}`. |
| POST | `/api/task/delete` |  | Delete a task: `{id}`. |
| POST | `/api/task/detail` |  | Full task record including its script: `{id}`. |
| GET | `/api/task/list` |  | Tasks with status, last run and trigger. |
| POST | `/api/task/update` |  | Update a task: `{id, name?, script?, frequency?, logs?, type?, enabled?, triggerType?, triggerValue?}`. |
| GET | `/api/task/status` |  | Compact status of all tasks (id, last run, running state). |
| POST | `/api/task/log` |  | Read a task's log: `{id}`. |
| GET | `/api/script/remote/list` | console only | Script Store listing (downloads the signed script database). Answers 503 with the reason when it cannot. |
| GET | `/api/script/remote/image/{key}` | console only | Script Store image. |
| POST | `/api/script/remote/execute` | console only | Run a Script Store script: `{key}`. |
| POST | `/api/script/remote/heartbeat` | console only | Keep-alive for a running remote script. |
| POST | `/api/script/execute` | console only | Run script source: `{script, type?}` where `type` is `rulescript` (default) or `lua`. |

## Statistics, decrypt & misc

| Method | Path | Flags | Description |
|---|---|---|---|
| GET | `/api/upload` | stream | Reserved streaming endpoint (no-op). |
| GET | `/api/stats/history` |  | Thermal history, optionally per title. Query: `titleID?`, `limit?` (max 1000). |
| GET | `/api/stats/playtime` |  | Cumulative playtime per title in seconds. |
| POST | `/api/stats/alert` |  | Overheat alert (`temperature`, `webhook`, `test`) and event webhook (`eventWebhook`, `events`) settings. |
| POST | `/api/decrypt/enqueue` | console only | Queue SELF decrypt jobs for a file or folder: `{path}`. Needs a native backend (see README). |
| GET | `/api/decrypt/list` | console only | Decrypt jobs with status. |
| POST | `/api/decrypt/cancel` | console only | Cancel a pending decrypt job: `{id}`. |
| POST | `/api/server/kill` |  | Stop the running AirPSX process (used to replace an old instance). |
| GET | `/api/docs` |  | Short machine-readable summary of the automation endpoints and webhook event names. |
| GET | `/api/blank` |  | Empty JSON response (connectivity check). |


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

