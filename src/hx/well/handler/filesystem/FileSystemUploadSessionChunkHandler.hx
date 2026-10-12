package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import airpsx.upload.UploadSessionManager;

// POST /api/fs/upload-session/chunk?id=...&offset=N with the raw chunk as the body (stream route).
// On an offset mismatch the response carries the server's `received` offset to resume from.
class FileSystemUploadSessionChunkHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        var id:String = request.query("id");
        var offset:Null<Int> = Std.parseInt(request.query("offset"));
        var length:Null<Int> = Std.parseInt(request.header("Content-Length"));
        if (id == null || offset == null || length == null)
            return {error: "id, offset and Content-Length are required"};

        return UploadSessionManager.writeChunk(id, offset, length, request.context.input);
    }
}
