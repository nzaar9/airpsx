package hx.well.handler.filesystem;
import sys.FileSystem;
import haxe.io.Path;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.fs.FileOps;
import airpsx.fs.FileJobs;

// POST /api/fs/batch {op: copy|move|delete, paths: [..], destination?}: multi-select operations as a background job.
// copy/move place each item inside `destination` (a directory). Poll /api/fs/job?id=...
class FileSystemBatchHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "op" => [ValidatorRule.Required, ValidatorRule.String],
            "destination" => [ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var op:String = request.input("op");
        if (op != "copy" && op != "move" && op != "delete")
            return {error: "op must be copy, move or delete"};

        var raw:Dynamic = request.input("paths");
        if (!(raw is Array) || (raw : Array<Dynamic>).length == 0)
            return {error: "paths must be a non-empty array"};
        var paths:Array<String> = [];
        for (p in (raw : Array<Dynamic>)) {
            var n = FileOps.normalize(Std.string(p));
            if (n == null || !FileSystem.exists(n))
                return {error: "Invalid or missing path: " + p};
            paths.push(n);
        }

        var destination:String = null;
        if (op != "delete") {
            destination = FileOps.normalize(request.input("destination"));
            if (destination == null || !FileSystem.exists(destination) || !FileSystem.isDirectory(destination))
                return {error: "destination must be an existing directory"};
        } else {
            for (p in paths)
                if (FileOps.isProtected(p))
                    return {error: "Refusing to delete protected path " + p};
        }

        var id = FileJobs.start("batch-" + op, () -> {
            var done = 0;
            var errors:Array<String> = [];
            for (p in paths) {
                try {
                    var target = destination + "/" + Path.withoutDirectory(p);
                    switch (op) {
                        case "copy":
                            if (FileSystem.exists(target)) throw "Destination exists: " + target;
                            FileOps.copy(p, target);
                        case "move": FileOps.move(p, target);
                        default: FileOps.remove(p);
                    }
                    done++;
                } catch (e) {
                    errors.push(p + ": " + Std.string(e));
                }
            }
            return {done: done, errors: errors};
        });
        return {job: id};
    }
}
