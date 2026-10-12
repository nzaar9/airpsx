package hx.well.handler.save;
#if orbis
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import airpsx.save.SaveBackupManager;

// POST /api/save/backups/run: starts a backup now (progress via /list).
class SaveBackupRunHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        return SaveBackupManager.runNow() ? {started: true} : {error: "A backup is already running"};
    }
}
#end
