package airpsx.save;
#if orbis
import sys.FileSystem;
import sys.FileStat;
import sys.io.File;
import sys.io.FileInput;
import haxe.Int64;
import haxe.io.Bytes;
import haxe.io.Output;
import haxe.tar.StreamTarFile;
import haxe.tar.TarEntry;
import airpsx.utils.FileUtils;
using StringTools;

class SaveBackupUtils {
    static var saveDirectories:Array<String> = ["savedata", "savedata_meta", "savedata_prospero", "savedata_prospero_meta"];
    // Entries below <profileId>/<save directory> are the only ones restore will ever write.
    static var restorable:EReg = ~/^[0-9a-f]{8}\/(savedata|savedata_meta|savedata_prospero|savedata_prospero_meta)(\/|$)/;

    /** All save files and folders of one profile, or of every profile when `profileId` is null/empty. */
    public static function collectFiles(?profileId:String):Array<String> {
        var profileIds = (profileId == null || profileId == "") ? FileSystem.readDirectory(Const.USER_HOME_PATH) : [profileId];
        var paths:Array<String> = [];
        for (id in profileIds)
            for (dir in saveDirectories)
                paths.push('${Const.USER_HOME_PATH}/${id}/${dir}');
        paths = paths.filter(p -> FileSystem.exists(p));
        return FileUtils.getRecursiveFiles(...paths);
    }

    /** Streams `files` (as returned by collectFiles) into `output` as a tar archive rooted at the user home. */
    public static function writeTar(output:Output, files:Array<String>):Void {
        var root = Const.USER_HOME_PATH;
        var queue = files.copy();
        new StreamTarFile().write(output, () -> {
            var file = queue.shift();
            if (file == null)
                return null;

            var entry = new TarEntry();
            entry.isDirectory = file.endsWith("/");
            entry.length = 0;
            if (!entry.isDirectory) {
                var stats:FileStat = FileSystem.stat(file);
                entry.length = stats.size;
                entry.input = File.read(file, true);
            }
            entry.name = file.substr(root.length + 1);
            return entry;
        });
    }

    /**
     * Extracts a backup tar into the user home, restricted to save directories. Existing files are replaced
     * via a temp file so a failed write never leaves a half-written save. Returns the number of files restored.
     */
    public static function restoreTar(tarPath:String, ?profileId:String):Int {
        var input = File.read(tarPath, true);
        var restored = 0;
        var longName:String = null;
        try {
            while (true) {
                var header = Bytes.alloc(512);
                if (input.readBytes(header, 0, 512) < 512 || isZero(header))
                    break;

                var name = cString(header, 0, 100);
                var prefix = cString(header, 345, 155);
                if (prefix != "")
                    name = prefix + "/" + name;
                var size = parseOctal(cString(header, 124, 12));
                var type = String.fromCharCode(header.get(156));
                var blocks = Std.int((size + 511) / 512) * 512;

                if (type == "L") { // GNU long name: payload is the name of the next entry
                    var data = Bytes.alloc(blocks);
                    input.readFullBytes(data, 0, blocks);
                    longName = cString(data, 0, size);
                    continue;
                }
                if (longName != null) {
                    name = longName;
                    longName = null;
                }

                var allowed = name.indexOf("..") == -1 && !name.startsWith("/") && restorable.match(name)
                    && (profileId == null || profileId == "" || name.startsWith(profileId + "/"));

                if (type == "5" || name.endsWith("/")) {
                    if (allowed) {
                        var dir = Const.USER_HOME_PATH + "/" + name;
                        if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
                    }
                } else if (type == "0" || type == "\x00") {
                    if (allowed) {
                        restoreFile(input, Const.USER_HOME_PATH + "/" + name, size);
                        restored++;
                    } else {
                        skip(input, blocks);
                        continue;
                    }
                    skip(input, blocks - size);
                    continue;
                }
                skip(input, blocks);
            }
        } catch (e) {
            input.close();
            throw e;
        }
        input.close();
        return restored;
    }

    static function restoreFile(input:FileInput, target:String, size:Int):Void {
        var dir = haxe.io.Path.directory(target);
        if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
        var temp = target + ".restoring";
        var out = File.write(temp, true);
        var buffer = Bytes.alloc(16384);
        var left = size;
        while (left > 0) {
            var n = input.readBytes(buffer, 0, Std.int(Math.min(buffer.length, left)));
            if (n <= 0) {
                out.close();
                FileSystem.deleteFile(temp);
                throw "Unexpected end of archive";
            }
            out.writeBytes(buffer, 0, n);
            left -= n;
        }
        out.close();
        if (FileSystem.exists(target)) FileSystem.deleteFile(target);
        FileSystem.rename(temp, target);
    }

    static function skip(input:FileInput, count:Int):Void {
        if (count > 0) input.readFullBytes(Bytes.alloc(count), 0, count);
    }

    static function isZero(bytes:Bytes):Bool {
        for (i in 0...bytes.length) if (bytes.get(i) != 0) return false;
        return true;
    }

    static function cString(bytes:Bytes, start:Int, max:Int):String {
        var end = start;
        while (end < start + max && end < bytes.length && bytes.get(end) != 0) end++;
        return bytes.getString(start, end - start);
    }

    static function parseOctal(s:String):Int {
        var v = 0;
        for (i in 0...s.length) {
            var c = s.charCodeAt(i);
            if (c >= 48 && c <= 55) v = v * 8 + (c - 48);
        }
        return v;
    }
}
#end
