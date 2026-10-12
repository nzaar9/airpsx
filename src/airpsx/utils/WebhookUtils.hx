package airpsx.utils;
import sys.thread.Thread;

class WebhookUtils {
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
