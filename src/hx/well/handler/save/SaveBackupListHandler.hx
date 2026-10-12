package hx.well.handler.save;
#if orbis
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.facades.DBStatic;

class SaveBackupListHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        return DBStatic.query('SELECT id, path, size, profileId, status, error, createdAt FROM save_backups ORDER BY id DESC LIMIT 200');
    }
}
#end
