package airpsx.upload;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Mutex;
import haxe.io.Bytes;
import haxe.io.Input;
import hx.well.facades.DBStatic;
import uuid.Uuid;
using StringTools;

/**
 * Resumable, chunked uploads. A session (upload_sessions in app.db) owns "<target>.part"; clients append
 * chunks at the offset the server reports, so a dropped connection, pause or server restart only loses the
 * chunk in flight. Limited to files below 2 GB because Haxe's seek/stat use 32-bit integers.
 */
class UploadSessionManager {
    public static inline var MAX_SIZE:Int = 2147483647;
    static var lock:Mutex = new Mutex();
    static var busy:Map<String, Bool> = new Map();

    public static function init(path:String, size:Int, overwrite:Bool):Dynamic {
        if (path.indexOf("..") != -1 || !path.startsWith("/") || path.endsWith("/"))
            return {error: "Invalid path"};
        if (size < 0 || size > MAX_SIZE)
            return {error: "Size must be between 0 and 2147483647 bytes"};
        if (!FileSystem.exists(haxe.io.Path.directory(path)))
            return {error: "Target directory not found"};
        if (FileSystem.exists(path) && !overwrite)
            return {error: "file exists"};

        // Resume an unfinished session for the same file instead of starting over.
        var rs = DBStatic.query('SELECT id FROM upload_sessions WHERE path = ? AND size = ? AND status = \'uploading\' ORDER BY createdAt DESC LIMIT 1', path, size);
        if (rs.hasNext()) {
            var existing = get(rs.next().id);
            if (existing != null && FileSystem.exists(path + ".part"))
                return existing;
        }

        var id = Uuid.v4();
        File.saveContent(path + ".part", "");
        DBStatic.query('INSERT INTO upload_sessions (id, path, size, received, status, updatedAt) VALUES (?, ?, ?, 0, \'uploading\', datetime(\'now\',\'localtime\'))', id, path, size);
        if (size == 0)
            return finish(get(id));
        return get(id);
    }

    public static function get(id:String):Dynamic {
        var rs = DBStatic.query('SELECT id, path, size, received, status, createdAt, updatedAt FROM upload_sessions WHERE id = ?', id);
        return rs.hasNext() ? rs.next() : null;
    }

    /** Writes `length` bytes read from `input` at `offset`. Returns the session state, or {error, received} on a mismatch. */
    public static function writeChunk(id:String, offset:Int, length:Int, input:Input):Dynamic {
        var session = get(id);
        if (session == null)
            return {error: "Session not found"};
        if (session.status != "uploading")
            return {error: "Session is " + session.status, received: session.received};

        var received:Int = session.received;
        var size:Int = session.size;
        if (offset != received)
            return {error: "Offset mismatch", received: received};
        if (length <= 0 || offset + length > size)
            return {error: "Invalid chunk length", received: received};

        lock.acquire();
        var alreadyBusy = busy.exists(id);
        if (!alreadyBusy) busy.set(id, true);
        lock.release();
        if (alreadyBusy)
            return {error: "Another chunk is in progress", received: received};

        try {
            var part:String = session.path + ".part";
            var out = File.update(part, true);
            out.seek(offset, SeekBegin);
            var buffer = Bytes.alloc(16384);
            var left = length;
            while (left > 0) {
                var n = input.readBytes(buffer, 0, Std.int(Math.min(buffer.length, left)));
                if (n <= 0)
                    break;
                out.writeBytes(buffer, 0, n);
                left -= n;
            }
            out.close();

            release(id);
            if (left > 0) // connection dropped mid-chunk: progress is not advanced, the client resends from `received`
                return {error: "Chunk incomplete", received: received};

            DBStatic.query('UPDATE upload_sessions SET received = ?, updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', offset + length, id);
            session = get(id);
            return offset + length == size ? finish(session) : session;
        } catch (e) {
            release(id);
            return {error: Std.string(e), received: received};
        }
    }

    public static function cancel(id:String):Bool {
        var session = get(id);
        if (session == null || session.status != "uploading")
            return false;
        try { FileSystem.deleteFile(session.path + ".part"); } catch (e) {}
        DBStatic.query('UPDATE upload_sessions SET status = \'cancelled\', updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', id);
        return true;
    }

    static function finish(session:Dynamic):Dynamic {
        var path:String = session.path;
        if (FileSystem.exists(path))
            FileSystem.deleteFile(path); // overwrite was approved at init
        FileSystem.rename(path + ".part", path);
        DBStatic.query('UPDATE upload_sessions SET status = \'done\', updatedAt = datetime(\'now\',\'localtime\') WHERE id = ?', session.id);
        return get(session.id);
    }

    static function release(id:String):Void {
        lock.acquire();
        busy.remove(id);
        lock.release();
    }
}
