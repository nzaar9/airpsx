package hx.well.handler.save;
#if orbis
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.save.SaveBackupManager;

// POST /api/save/backups/restore {id, profileId?}: restores one backup (optionally a single profile). Overwrites current saves.
class SaveBackupRestoreHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "id" => [ValidatorRule.Required, ValidatorRule.Int],
            "profileId" => [ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var profileId:String = request.input("profileId");
        if (profileId != null && profileId != "" && !~/^[0-9a-f]{8}$/.match(profileId))
            return {error: "Invalid profileId"};
        return SaveBackupManager.restore(request.input("id"), profileId);
    }
}
#end
