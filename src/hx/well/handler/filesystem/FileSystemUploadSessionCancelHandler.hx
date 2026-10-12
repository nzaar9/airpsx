package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.upload.UploadSessionManager;

// POST /api/fs/upload-session/cancel {id}: discards the partial file. Pausing needs no call: just stop sending chunks.
class FileSystemUploadSessionCancelHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "id" => [ValidatorRule.Required, ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        return {success: UploadSessionManager.cancel(request.input("id"))};
    }
}
