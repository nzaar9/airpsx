package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import airpsx.fs.FileJobs;

// GET /api/fs/job?id=N: status of a batch/archive job (running, done or failed, with its result).
class FileSystemJobHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        var id = Std.parseInt(request.query("id"));
        // Typed explicitly: an untyped `var` is inferred as Response and the job would be cast to null.
        var job:Dynamic = id != null ? FileJobs.get(id) : null;
        if (job == null) {
            var notFound:Dynamic = {error: "Job not found"};
            return notFound;
        }
        return job;
    }
}
