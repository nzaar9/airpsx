package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import airpsx.upload.UploadSessionManager;
import airpsx.utils.RequestBodyUtils;
import airpsx.utils.RequestBodyUtils.CountingInput;

// POST /api/fs/upload-session/chunk?id=...&offset=N with the raw chunk as the body (stream route).
// On an offset mismatch the response carries the server's `received` offset to resume from.
class FileSystemUploadSessionChunkHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        var id:String = request.query("id");
        var offset:Null<Int> = Std.parseInt(request.query("offset"));
        var length:Null<Int> = Std.parseInt(request.header("Content-Length"));
        if (id == null || offset == null || length == null)
            return {error: "id, offset and Content-Length are required"};

        // Always consume the whole body, even when rejecting the chunk: otherwise the connection is reset
        // and the client sees a "Network error" instead of the offset it should resume from.
        var input = new CountingInput(request.context.input);
        // Typed explicitly: an untyped `var` is inferred as Response and the result would be cast to null.
        var result:Dynamic = UploadSessionManager.writeChunk(id, offset, length, input);
        RequestBodyUtils.drain(request.context.input, length - input.count);
        return result;
    }
}
