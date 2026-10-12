package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.facades.DBStatic;
import airpsx.upload.UploadSessionManager;

// GET /api/fs/upload-session/status?id=...  -> one session (to resume), or without id the unfinished sessions.
class FileSystemUploadSessionStatusHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        var id:String = request.query("id");
        if (id == null || id == "")
            return DBStatic.query('SELECT id, path, size, received, status, updatedAt FROM upload_sessions WHERE status = \'uploading\' ORDER BY createdAt DESC');

        var session = UploadSessionManager.get(id);
        return session != null ? session : {error: "Session not found"};
    }
}
