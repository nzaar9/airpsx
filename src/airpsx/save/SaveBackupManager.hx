package airpsx.save;
#if orbis
import sys.FileSystem;
import sys.io.File;
import sys.thread.Mutex;
import sys.thread.Thread;
import hx.well.facades.DBStatic;
import cpp.lib.LibKernel;
import cpp.lib.Process;
import airpsx.utils.SettingsUtils;
using StringTools;

/**
 * Scheduled save backups. Settings live in the settings table (backup.*); each run writes a tar into the
 * destination directory (a USB drive or any mounted NAS share, e.g. /mnt/usb0/airpsx) and records it in
 * save_backups. Old archives beyond `backup.keep` are pruned, so every kept file is a restorable version.
 */
class SaveBackupManager {
    static var stateLock:Mutex = new Mutex();
    static var running:Bool = false;

    public static function config():Dynamic {
        return {
            enabled: SettingsUtils.get("backup.enabled", "0") == "1",
            intervalHours: Std.parseInt(SettingsUtils.get("backup.intervalHours", "24")),
            destination: SettingsUtils.get("backup.destination", '${Const.DATA_PATH}/backups'),
            keep: Std.parseInt(SettingsUtils.get("backup.keep", "5")),
            profileId: SettingsUtils.get("backup.profileId", ""),
            lastRun: SettingsUtils.get("backup.lastRun", "")
        };
    }

    /** Returns an error message, or null when the destination is usable. */
    public static function checkDestination(dir:String):Null<String> {
        if (dir.indexOf("..") != -1 || !dir.startsWith("/"))
            return "Destination must be an absolute path";
        var parent = haxe.io.Path.directory(dir.endsWith("/") ? dir.substr(0, dir.length - 1) : dir);
        if (!FileSystem.exists(dir) && !FileSystem.exists(parent))
            return "Destination (or its parent folder) does not exist";
        return null;
    }

    /** Called every minute by the scheduler. */
    public static function tick():Void {
        var cfg = config();
        if (!cfg.enabled || airpsx.utils.MaintenanceUtils.enabled())
            return;
        var last = Std.parseFloat(cfg.lastRun);
        if (!Math.isNaN(last) && Sys.time() - last < cfg.intervalHours * 3600)
            return;
        runNow(true);
    }

    /** Starts a backup on a worker thread. Returns false if one is already running. */
    public static function runNow(?silent:Bool = false):Bool {
        stateLock.acquire();
        var alreadyRunning = running;
        running = true;
        stateLock.release();
        if (alreadyRunning)
            return false;

        Thread.create(() -> {
            try { backup(silent); } catch (e) { trace('backup failed: ${e}'); }
            stateLock.acquire();
            running = false;
            stateLock.release();
        });
        return true;
    }

    static function backup(silent:Bool):Void {
        var cfg = config();
        var dir:String = cfg.destination;
        var error = checkDestination(dir);
        var id = -1;
        var finalPath = "";
        try {
            if (error != null) throw error;
            if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);

            // Count the attempt so a failing destination is retried at the configured interval, not every minute.
            SettingsUtils.set("backup.lastRun", Std.string(Sys.time()));

            var stamp = DateTools.format(Date.now(), "%Y%m%d_%H%M%S");
            var profile:String = cfg.profileId;
            finalPath = '${dir.endsWith("/") ? dir.substr(0, dir.length - 1) : dir}/${#if prospero "ps5" #else "ps4" #end}_savebackup_${stamp}${profile != "" ? "_" + profile : ""}.tar';
            id = DBStatic.connection(airpsx.type.DatabaseType.DEFAULT).insert('INSERT INTO save_backups (path, profileId, status) VALUES (?, ?, \'running\')', finalPath, profile);

            var temp = finalPath + ".tmp";
            var out = File.write(temp, true);
            try {
                SaveBackupUtils.writeTar(out, SaveBackupUtils.collectFiles(profile));
            } catch (e) {
                out.close();
                try { FileSystem.deleteFile(temp); } catch (_) {}
                throw e;
            }
            out.close();
            FileSystem.rename(temp, finalPath);

            DBStatic.query('UPDATE save_backups SET status = \'done\', size = ? WHERE id = ?', FileSystem.stat(finalPath).size, id);
            prune(dir, cfg.keep, profile);
            if (!silent) LibKernel.sendNotificationRequest('Save backup finished');
            airpsx.utils.WebhookUtils.emit("backup_done", {path: finalPath});
        } catch (e) {
            if (id != -1)
                DBStatic.query('UPDATE save_backups SET status = \'failed\', error = ? WHERE id = ?', Std.string(e), id);
            LibKernel.sendNotificationRequest('Save backup failed: ${e}');
            airpsx.utils.WebhookUtils.emit("backup_failed", {error: Std.string(e)});
        }
    }

    // Keeps the newest `keep` successful backups of the same scope (same profile filter) in this destination.
    static function prune(dir:String, keep:Int, profile:String):Void {
        if (keep == null || keep < 1)
            return;
        var rs = DBStatic.query('SELECT id, path FROM save_backups WHERE status = \'done\' AND profileId = ? ORDER BY id DESC LIMIT -1 OFFSET ?', profile, keep);
        var old:Array<Dynamic> = [];
        while (rs.hasNext()) old.push(rs.next());
        for (row in old)
            delete(row.id);
    }

    public static function delete(id:Int):Bool {
        var rs = DBStatic.query('SELECT path FROM save_backups WHERE id = ?', id);
        if (!rs.hasNext())
            return false;
        var path:String = rs.next().path;
        try { if (FileSystem.exists(path)) FileSystem.deleteFile(path); } catch (e) { return false; }
        DBStatic.query('DELETE FROM save_backups WHERE id = ?', id);
        return true;
    }

    /** Restores a backup into the user home. Refused while a game is running (it may hold the save open). */
    public static function restore(id:Int, ?profileId:String):Dynamic {
        if (Process.getRunningApp() != null)
            return {error: "Close the running game before restoring saves"};
        var rs = DBStatic.query('SELECT path FROM save_backups WHERE id = ? AND status = \'done\'', id);
        if (!rs.hasNext())
            return {error: "Backup not found"};
        var path:String = rs.next().path;
        if (!FileSystem.exists(path))
            return {error: "Backup file is missing (is the drive mounted?)"};
        try {
            return {restored: SaveBackupUtils.restoreTar(path, profileId)};
        } catch (e) {
            return {error: Std.string(e)};
        }
    }
}
#end
