package hx.well.handler.stats;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.utils.SettingsUtils;
import airpsx.utils.WebhookUtils;

// POST /api/stats/alert  {temperature?:Int, webhook?:String, test?:Bool}; an empty field clears the value.
// With no fields it returns the current settings.
class AlertSettingsHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "temperature" => [ValidatorRule.Int],
            "webhook" => [ValidatorRule.String],
            "test" => [ValidatorRule.Bool],
            "eventWebhook" => [ValidatorRule.String],
            "events" => [ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var temperature:Dynamic = request.input("temperature");
        var webhook:String = request.input("webhook");

        if (temperature != null)
            SettingsUtils.set("alert.temperature", Std.string(temperature));

        if (webhook != null) {
            if (webhook != "" && !(StringTools.startsWith(webhook, "http://") || StringTools.startsWith(webhook, "https://")))
                return {error: "webhook must be an http(s) URL"};
            SettingsUtils.set("alert.webhook", webhook);
        }

        // Outbound event webhook (game_launch, game_close, backup_done, backup_failed); `events` is a comma separated allow-list.
        var eventWebhook:String = request.input("eventWebhook");
        if (eventWebhook != null) {
            if (eventWebhook != "" && !(StringTools.startsWith(eventWebhook, "http://") || StringTools.startsWith(eventWebhook, "https://")))
                return {error: "eventWebhook must be an http(s) URL"};
            SettingsUtils.set("webhook.url", eventWebhook);
        }
        var events:String = request.input("events");
        if (events != null)
            SettingsUtils.set("webhook.events", events);

        var url = SettingsUtils.get("alert.webhook", "");
        if (request.input("test", false) == true)
            WebhookUtils.send(url, "AirPSX test alert");

        return {
            temperature: SettingsUtils.get("alert.temperature", ""),
            webhook: url,
            eventWebhook: SettingsUtils.get("webhook.url", ""),
            events: SettingsUtils.get("webhook.events", "")
        };
    }
}
