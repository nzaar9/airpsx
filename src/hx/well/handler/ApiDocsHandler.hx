package hx.well.handler;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;

// GET /api/docs: machine-readable summary of the HTTP API added for automation (Home Assistant, scripts).
// Maintained by hand next to ApiRoute: update it when a route is added. Paths are relative to /api.
class ApiDocsHandler extends AbstractHandler {
    static var routes:Array<Dynamic> = [
        {m: "POST", p: "/task/update", d: "Set task fields incl. triggerType (cron|boot|game_launch|game_close|temp_above) and triggerValue"},
        {m: "GET", p: "/stats/history", d: "Thermal history. Query: titleID?, limit?"},
        {m: "GET", p: "/stats/playtime", d: "Cumulative playtime per title (seconds)"},
        {m: "POST", p: "/stats/alert", d: "Get/set overheat alert (temperature, webhook, test) and event webhook (eventWebhook, events)"},
        {m: "POST", p: "/decrypt/enqueue", d: "Queue SELF decrypt jobs (console only; needs a native backend)"},
        {m: "GET", p: "/decrypt/list", d: "SELF decrypt jobs"},
        {m: "POST", p: "/decrypt/cancel", d: "Cancel a pending decrypt job"},
        {m: "POST", p: "/package/preview", d: "PKG metadata: {path}"},
        {m: "POST", p: "/package/queue/add", d: "Queue PKG installs: {source} URL, file or directory"},
        {m: "GET", p: "/package/queue/list", d: "Install queue"},
        {m: "POST", p: "/package/queue/cancel", d: "Cancel or retry a queue entry: {id, retry?}"},
        {m: "POST", p: "/fs/upload-session/init", d: "Start/resume chunked upload: {path, size, overwrite?}"},
        {m: "POST", p: "/fs/upload-session/chunk", d: "Upload a chunk. Query: id, offset; raw body"},
        {m: "GET", p: "/fs/upload-session/status", d: "Upload session state. Query: id?"},
        {m: "POST", p: "/fs/upload-session/cancel", d: "Cancel an upload: {id}"},
        {m: "POST", p: "/fs/search", d: "Name search: {path, query, limit?}"},
        {m: "POST", p: "/fs/batch", d: "Multi-select copy/move/delete: {op, paths, destination?} -> job"},
        {m: "POST", p: "/fs/archive", d: "zip/unzip: {action, paths|path, output|destination} -> job"},
        {m: "GET", p: "/fs/job", d: "Background job status. Query: id"},
        {m: "POST", p: "/fs/text", d: "Read or save a text file: {path, content?}"},
        {m: "POST", p: "/fs/hex", d: "Hex view: {path, offset?, length?}"},
        {m: "POST", p: "/save/backups/config", d: "Scheduled save backup settings"},
        {m: "POST", p: "/save/backups/run", d: "Run a save backup now"},
        {m: "GET", p: "/save/backups/list", d: "Save backups"},
        {m: "POST", p: "/save/backups/restore", d: "Restore a save backup: {id, profileId?}"},
        {m: "POST", p: "/save/backups/delete", d: "Delete a save backup: {id}"},
        {m: "POST", p: "/process/kill", d: "Signal a process: {pid, force?}"},
        {m: "POST", p: "/app/uninstall/{titleId}", d: "Uninstall a title"}
    ];

    public function execute(request:Request):AbstractResponse {
        return {
            events: ["game_launch", "game_close", "backup_done", "backup_failed"],
            routes: routes
        };
    }
}
