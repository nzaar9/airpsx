package airpsx.fs;
import sys.thread.Thread;
import sys.thread.Mutex;

/** In-memory background jobs for slow file operations, so they never occupy one of the few HTTP threads. */
class FileJobs {
    static var jobs:Map<Int, Dynamic> = new Map();
    static var nextId:Int = 1;
    static var lock:Mutex = new Mutex();
    static inline var KEEP:Int = 50;

    public static function start(kind:String, work:Void->Dynamic):Int {
        lock.acquire();
        var id = nextId++;
        jobs.set(id, {id: id, kind: kind, status: "running", started: Sys.time()});
        jobs.remove(id - KEEP);
        lock.release();

        Thread.create(() -> {
            var result:Dynamic = {};
            var status = "done";
            try {
                var r = work();
                if (r != null) result = r;
            } catch (e) {
                status = "failed";
                result = {error: Std.string(e)};
            }
            lock.acquire();
            jobs.set(id, {id: id, kind: kind, status: status, result: result, started: jobs.get(id).started, finished: Sys.time()});
            lock.release();
        });
        return id;
    }

    public static function get(id:Int):Dynamic {
        lock.acquire();
        var job = jobs.get(id);
        lock.release();
        return job;
    }
}
