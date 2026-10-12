package hx.well.handler.pkg;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.facades.DBStatic;

class InstallQueueListHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        return DBStatic.query('SELECT id, source, name, titleID, contentID, status, error, createdAt, updatedAt FROM install_queue ORDER BY id DESC LIMIT 500');
    }
}
