package hx.well.handler.filesystem;
import sys.FileSystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.fs.FileOps;
import airpsx.fs.FileJobs;

// POST /api/fs/archive {action: zip, paths: [..], output} or {action: unzip, path, destination}. Background job.
// Archives are handled in memory, so zip is limited to 64 MB per file / 256 MB total and unzip to 256 MB archives.
class FileSystemArchiveHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "action" => [ValidatorRule.Required, ValidatorRule.String],
            "output" => [ValidatorRule.String],
            "path" => [ValidatorRule.String],
            "destination" => [ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var action:String = request.input("action");
        if (action == "zip") {
            var raw:Dynamic = request.input("paths");
            var output = FileOps.normalize(request.input("output"));
            if (!(raw is Array) || (raw : Array<Dynamic>).length == 0 || output == null)
                return {error: "paths (non-empty array) and output are required"};
            var paths:Array<String> = [];
            for (p in (raw : Array<Dynamic>)) {
                var n = FileOps.normalize(Std.string(p));
                if (n == null || !FileSystem.exists(n))
                    return {error: "Invalid or missing path: " + p};
                paths.push(n);
            }
            return {job: FileJobs.start("zip", () -> { FileOps.zip(paths, output); return {output: output}; })};
        }
        if (action == "unzip") {
            var path = FileOps.normalize(request.input("path"));
            var destination = FileOps.normalize(request.input("destination"));
            if (path == null || destination == null || !FileSystem.exists(path) || FileSystem.isDirectory(path))
                return {error: "path (existing zip) and destination are required"};
            return {job: FileJobs.start("unzip", () -> { return {extracted: FileOps.unzip(path, destination)}; })};
        }
        return {error: "action must be zip or unzip"};
    }
}
