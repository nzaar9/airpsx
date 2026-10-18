package airpsx.install;
import sys.FileSystem;
import sys.thread.Thread;
import sys.thread.Mutex;
import hx.well.facades.DBStatic;
import airpsx.utils.DbUtils;
using StringTools;
#if orbis
import cpp.lib.LibSceAppInstUtil;
#end

/**
 * Persistent PKG install queue (install_queue table in app.db). One worker submits packages to the
 * system installer sequentially, with a pause between submissions. The installer API is fire-and-forget,
 * so status 'submitted' means "handed to the console"; the console's own download UI shows progress.
 * Entries left 'running' by a crash are reset to 'pending' at startup and resume().
 */
class InstallQueueManager {
    static inline var PAUSE_SECONDS:Float = 5;
    static var lock:Mutex = new Mutex();
    static var workerRunning:Bool = false;

    /** Queue a URL, a local .pkg, or every .pkg directly inside a directory (USB / mounted share). Returns jobs created. */
    public static function enqueue(source:String):Int {
        var isUrl = source.startsWith("http://") || source.startsWith("https://");
        if (!isUrl && (source.indexOf("..") != -1 || !source.startsWith("/") || !FileSystem.exists(source)))
            return 0;

        var count = 0;
        if (!isUrl && FileSystem.isDirectory(source)) {
            for (entry in FileSystem.readDirectory(source))
                count += enqueueFile(source.endsWith("/") ? source + entry : source + "/" + entry);
        } else {
            count = enqueueFile(source);
        }
        if (count > 0)
            ensureWorker();
        return count;
    }

    static function enqueueFile(source:String):Int {
        var isUrl = source.startsWith("http://") || source.startsWith("https://");
        var name = source.split("/").pop();
        var titleId = "";
        var contentId = "";
        if (!isUrl) {
            if (!source.toLowerCase().endsWith(".pkg") || FileSystem.isDirectory(source))
                return 0;
            var info = PkgMetadata.read(source);
            if (info != null) {
                titleId = info.titleId;
                contentId = info.contentId;
                if (info.title != null) name = info.title;
            }
        }
        DBStatic.query('INSERT INTO install_queue (source, name, titleID, contentID, updatedAt) VALUES (?, ?, ?, ?, datetime(\'now\',\'localtime\'))', source, name, titleId, contentId);
        return 1;
    }

    public static function cancel(id:Int):Bool {
        DBStatic.query('UPDATE install_queue SET status = \'cancelled\', updatedAt = datetime(\'now\',\'localtime\') WHERE id = ? AND status = \'pending\'', id);
        var row:Dynamic = DbUtils.first('SELECT status FROM install_queue WHERE id = ?', id);
        return row != null && row.status == "cancelled";
    }

    /** Re-queue a failed or cancelled entry. */
    public static function retry(id:Int):Bool {
        DBStatic.query('UPDATE install_queue SET status = \'pending\', error = NULL, updatedAt = datetime(\'now\',\'localtime\') WHERE id = ? AND status IN (\'failed\', \'cancelled\')', id);
        var row:Dynamic = DbUtils.first('SELECT status FROM install_queue WHERE id = ?', id);
        var ok = row != null && row.status == "pending";
        if (ok) ensureWorker();
        return ok;
    }

    public static function resume():Void {
        if (DbUtils.exists('SELECT 1 FROM install_queue WHERE status = \'pending\' LIMIT 1'))
            ensureWorker();
    }

    static function ensureWorker():Void {
        lock.acquire();
        var start = !workerRunning;
        workerRunning = true;
        lock.release();
        if (start)
            Thread.create(() -> {
                try { work(); } catch (e) {}
                // A thread's database connections are only released explicitly; without this each worker run leaks one.
                hx.well.database.Connection.free();
            });
    }

    static function work():Void {
        try {
            while (true) {
                var job:Dynamic = DbUtils.first('SELECT id, source, name FROM install_queue WHERE status = \'pending\' ORDER BY id LIMIT 1');
                if (job == null || airpsx.utils.MaintenanceUtils.enabled()) {
                    // Decide to exit and clear the flag under one lock, then re-check, so an enqueue racing with
                    // the exit either sees the worker still running or starts a new one.
                    lock.acquire();
                    var again = job == null && DbUtils.exists('SELECT 1 FROM install_queue WHERE status = \'pending\' LIMIT 1') && !airpsx.utils.MaintenanceUtils.enabled();
                    if (!again) workerRunning = false;
                    lock.release();
                    if (again) continue;
                    return;
                }
                var id:Int = job.id;
                DBStatic.query('UPDATE install_queue SET status = \'running\', updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', id);
                try {
                    var source:String = job.source;
                    if (!source.startsWith("http") && !FileSystem.exists(source))
                        throw "File not found";
                    #if orbis
                    var code:Int = LibSceAppInstUtil.appInstUtilInstallByPackage(source, job.name);
                    if (code != 0)
                        throw 'Installer rejected the package (code ${code})';
                    #else
                    throw "Installing is only supported on the console";
                    #end
                    DBStatic.query('UPDATE install_queue SET status = \'submitted\', error = NULL, updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', id);
                } catch (e) {
                    DBStatic.query('UPDATE install_queue SET status = \'failed\', error = ?, updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', Std.string(e), id);
                }
                Sys.sleep(PAUSE_SECONDS);
            }
        } catch (e) {
            trace('install worker stopped: ${e}');
            lock.acquire();
            workerRunning = false;
            lock.release();
        }
    }
}
