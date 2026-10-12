package hx.well.handler.filesystem;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import airpsx.fs.FileJobs;

// GET /api/fs/job?id=N: status of a batch/archive job (running, done or failed, with its result).
class FileSystemJobHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        var id = Std.parseInt(request.query("id"));
        var job = id != null ? FileJobs.get(id) : null;
        return job != null ? job : {error: "Job not found"};
    }
}
