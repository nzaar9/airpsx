package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.fs.FileOps;

// POST /api/fs/text {path} reads a text file (<= 1 MB); with `content` it saves it (atomically, via a temp file).
class FileSystemTextHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "path" => [ValidatorRule.Required, ValidatorRule.String],
            "content" => [ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var path = FileOps.normalize(request.input("path"));
        if (path == null)
            return {error: "Invalid path"};
        var content:String = request.input("content");
        if (content == null)
            return FileOps.readText(path);
        try {
            FileOps.writeText(path, content);
        } catch (e) {
            return {error: Std.string(e)};
        }
        return {success: true};
    }
}
