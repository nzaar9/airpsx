package hx.well.handler.save;
#if orbis
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.save.SaveBackupManager;
import airpsx.utils.SettingsUtils;

// POST /api/save/backups/config {enabled?, intervalHours?, destination?, keep?, profileId?}; no fields returns the config.
class SaveBackupConfigHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "enabled" => [ValidatorRule.Bool],
            "intervalHours" => [ValidatorRule.Int],
            "destination" => [ValidatorRule.String],
            "keep" => [ValidatorRule.Int],
            "profileId" => [ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var destination:String = request.input("destination");
        if (destination != null) {
            var error = SaveBackupManager.checkDestination(destination);
            if (error != null) return {error: error};
            SettingsUtils.set("backup.destination", destination);
        }

        var intervalHours:Null<Int> = request.input("intervalHours");
        if (intervalHours != null) {
            if (intervalHours < 1) return {error: "intervalHours must be at least 1"};
            SettingsUtils.set("backup.intervalHours", Std.string(intervalHours));
        }

        var keep:Null<Int> = request.input("keep");
        if (keep != null) {
            if (keep < 1) return {error: "keep must be at least 1"};
            SettingsUtils.set("backup.keep", Std.string(keep));
        }

        var profileId:String = request.input("profileId");
        if (profileId != null) {
            if (profileId != "" && !~/^[0-9a-f]{8}$/.match(profileId)) return {error: "Invalid profileId"};
            SettingsUtils.set("backup.profileId", profileId);
        }

        var enabled:Dynamic = request.input("enabled");
        if (enabled != null)
            SettingsUtils.set("backup.enabled", enabled == true ? "1" : "0");

        return SaveBackupManager.config();
    }
}
#end
