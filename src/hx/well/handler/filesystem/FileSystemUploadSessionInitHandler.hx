package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.upload.UploadSessionManager;

// POST /api/fs/upload-session/init {path, size, overwrite?}: starts (or resumes) a chunked upload.
// Returns the session; upload chunks starting at its `received` offset.
class FileSystemUploadSessionInitHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "path" => [ValidatorRule.Required, ValidatorRule.String],
            "size" => [ValidatorRule.Required, ValidatorRule.Int],
            "overwrite" => [ValidatorRule.Bool]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        return UploadSessionManager.init(request.input("path"), request.input("size"), request.input("overwrite", false) == true);
    }
}
