package hx.well.handler.decrypt;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.facades.DBStatic;

class DecryptListHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        return DBStatic.query('SELECT id, path, output, status, error, createdAt, updatedAt FROM decrypt_jobs ORDER BY id DESC LIMIT 500');
    }
}
