package hx.well.handler.filesystem;
import sys.FileSystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.fs.FileOps;

// POST /api/fs/search {path, query, limit?}: recursive, case-insensitive name search (bounded by count and time).
class FileSystemSearchHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "path" => [ValidatorRule.Required, ValidatorRule.String],
            "query" => [ValidatorRule.Required, ValidatorRule.String],
            "limit" => [ValidatorRule.Int]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var path = FileOps.normalize(request.input("path"));
        if (path == null || !FileSystem.exists(path) || !FileSystem.isDirectory(path))
            return {error: "Invalid search path"};
        var query:String = request.input("query");
        if (query == "")
            return {error: "query is empty"};
        var limit:Int = request.input("limit", 200);
        return FileOps.search(path, query, Std.int(Math.max(1, Math.min(limit, 1000))));
    }
}
