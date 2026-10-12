package airpsx.utils;
import sys.thread.Thread;
import airpsx.utils.SettingsUtils;

class WebhookUtils {
    /**
     * Outbound event webhook (Home Assistant, n8n, ...): POSTs {event, time, data} to `webhook.url`
     * when set. `webhook.events` is an optional comma separated allow-list; empty means all events.
     */
    public static function emit(event:String, ?data:Dynamic):Void {
        try {
            var url = SettingsUtils.get("webhook.url", "");
            if (url == "") return;
            var allowed = SettingsUtils.get("webhook.events", "");
            if (allowed != "" && allowed.split(",").map(StringTools.trim).indexOf(event) == -1) return;
            post(url, {event: event, time: Date.now().toString(), data: data});
        } catch (e) {
            trace('webhook emit failed: ${e}');
        }
    }

    static function post(url:String, payload:Dynamic):Void {
        if (!(StringTools.startsWith(url, "http://") || StringTools.startsWith(url, "https://")))
            return;
        Thread.create(() -> {
            try {
                var h = new haxe.Http(url);
                h.cnxTimeout = 10;
                h.setHeader("Content-Type", "application/json");
                h.setPostData(haxe.Json.stringify(payload));
                h.onError = (e) -> trace('webhook error: ${e}');
                h.request(true);
            } catch (e) {
                trace('webhook failed: ${e}');
            }
        });
    }

    /**
     * POSTs a JSON message to an http(s) webhook. The body carries both "content" (Discord)
     * and "text" (Slack / generic receivers). Fire-and-forget on a worker thread.
     * Telegram's bot API needs a chat_id, so use a webhook URL that already includes it.
     */
    public static function send(url:String, message:String, ?extra:Dynamic):Void {
        if (url == null || !(StringTools.startsWith(url, "http://") || StringTools.startsWith(url, "https://")))
            return;

        Thread.create(() -> {
            try {
                var payload:Dynamic = {content: message, text: message};
                if (extra != null)
                    for (f in Reflect.fields(extra))
                        Reflect.setField(payload, f, Reflect.field(extra, f));
                var h = new haxe.Http(url);
                h.cnxTimeout = 10;
                h.setHeader("Content-Type", "application/json");
                h.setPostData(haxe.Json.stringify(payload));
                h.onError = (e) -> trace('webhook error: ${e}');
                h.request(true);
            } catch (e) {
                trace('webhook failed: ${e}');
            }
        });
    }
}
