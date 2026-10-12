package airpsx.decrypt;
import sys.FileSystem;
import sys.thread.Thread;
import sys.thread.Mutex;
import hx.well.facades.DBStatic;
using StringTools;

/**
 * Persistent SELF decrypt queue. Jobs live in app.db (decrypt_jobs); one worker thread processes them
 * sequentially so the HTTP pool is never blocked. Jobs left 'running' by a crash are reset to 'pending'
 * at startup (SetupDatabaseCommand) and picked up again by resume().
 */
class SelfDecryptManager {
    public static var backend:SelfDecryptBackend = new UnsupportedSelfBackend();
    public static inline var OUTPUT_PATH:String = '${Const.DATA_PATH}/decrypted';
    static var extensions:Array<String> = ["bin", "sprx", "elf", "self", "prx"];
    static var lock:Mutex = new Mutex();
    static var workerRunning:Bool = false;

    /** Queue a file, or every candidate file below a directory. Returns the number of jobs created. */
    public static function enqueue(path:String):Int {
        if (path.indexOf("..") != -1 || !path.startsWith("/") || !FileSystem.exists(path))
            return 0;

        var count = 0;
        if (FileSystem.isDirectory(path)) {
            for (entry in FileSystem.readDirectory(path))
                count += enqueue(path.endsWith("/") ? path + entry : path + "/" + entry);
        } else if (extensions.contains(path.split(".").pop().toLowerCase())) {
            var output = OUTPUT_PATH + path;
            DBStatic.query('INSERT INTO decrypt_jobs (path, output, updatedAt) VALUES (?, ?, datetime(\'now\',\'localtime\'))', path, output);
            count++;
        }
        if (count > 0)
            ensureWorker();
        return count;
    }

    public static function cancel(id:Int):Bool {
        DBStatic.query('UPDATE decrypt_jobs SET status = \'cancelled\', updatedAt = datetime(\'now\',\'localtime\') WHERE id = ? AND status = \'pending\'', id);
        var rs = DBStatic.query('SELECT status FROM decrypt_jobs WHERE id = ?', id);
        return rs.hasNext() && rs.next().status == "cancelled";
    }

    /** Called at boot to continue jobs interrupted by a restart or crash. */
    public static function resume():Void {
        var rs = DBStatic.query('SELECT COUNT(*) AS c FROM decrypt_jobs WHERE status = \'pending\'');
        if (rs.hasNext() && (rs.next().c : Int) > 0)
            ensureWorker();
    }

    static function ensureWorker():Void {
        lock.acquire();
        var start = !workerRunning;
        workerRunning = true;
        lock.release();
        if (start)
            Thread.create(work);
    }

    static function work():Void {
        try {
            while (true) {
                var rs = DBStatic.query('SELECT id, path, output FROM decrypt_jobs WHERE status = \'pending\' ORDER BY id LIMIT 1');
                if (!rs.hasNext() || airpsx.utils.MaintenanceUtils.enabled()) {
                    // Decide to exit and clear the flag under one lock, then re-check, so an enqueue racing with
                    // the exit either sees the worker still running or starts a new one.
                    lock.acquire();
                    var again = rs.hasNext() ? false : DBStatic.query('SELECT 1 FROM decrypt_jobs WHERE status = \'pending\' LIMIT 1').hasNext() && !airpsx.utils.MaintenanceUtils.enabled();
                    if (!again) workerRunning = false;
                    lock.release();
                    if (again) continue;
                    return;
                }
                var job:Dynamic = rs.next();
                var id:Int = job.id;
                // Persist state before touching the file: a panic mid-dump must leave the job resumable.
                DBStatic.query('UPDATE decrypt_jobs SET status = \'running\', updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', id);
                try {
                    if (!backend.supported())
                        throw "No SELF decrypt backend is installed in this build";
                    var output:String = job.output;
                    FileSystem.createDirectory(haxe.io.Path.directory(output)); // recursive in sys
                    backend.decrypt(job.path, output);
                    DBStatic.query('UPDATE decrypt_jobs SET status = \'done\', error = NULL, updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', id);
                } catch (e) {
                    DBStatic.query('UPDATE decrypt_jobs SET status = \'failed\', error = ?, updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', Std.string(e), id);
                }
            }
        } catch (e) {
            trace('decrypt worker stopped: ${e}');
            lock.acquire();
            workerRunning = false;
            lock.release();
        }
    }
}
