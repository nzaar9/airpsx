package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.fs.FileOps;

// POST /api/fs/hex {path, offset?, length?}: up to 4096 bytes as hex plus an ASCII column (read-only hex viewer).
class FileSystemHexHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "path" => [ValidatorRule.Required, ValidatorRule.String],
            "offset" => [ValidatorRule.Int],
            "length" => [ValidatorRule.Int]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var path = FileOps.normalize(request.input("path"));
        if (path == null)
            return {error: "Invalid path"};
        return FileOps.readHex(path, request.input("offset", 0), request.input("length", 512));
    }
}
