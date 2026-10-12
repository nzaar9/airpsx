package airpsx.fs;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Bytes;
import haxe.io.Path;
using StringTools;

/** File manager operations: search, copy/move/delete, zip/unzip, text and hex access. Paths must be absolute, without "..". */
class FileOps {
    static var protectedPaths:Array<String> = ["/", "/user", "/user/home", "/system", "/system_ex", "/system_data", "/data", "/mnt", "/dev", "/preinst", "/update"];
    public static inline var MAX_TEXT_SIZE:Int = 1024 * 1024;
    static inline var MAX_ZIP_FILE:Int = 64 * 1024 * 1024;
    static inline var MAX_ZIP_TOTAL:Int = 256 * 1024 * 1024;

    public static function normalize(path:String):Null<String> {
        if (path == null || !path.startsWith("/") || path.indexOf("..") != -1 || path.indexOf("\x00") != -1)
            return null;
        // Canonical form: no empty or "." segments, so "//user/./home" cannot dodge the protected-path check.
        var parts = path.split("/").filter(s -> s != "" && s != ".");
        return "/" + parts.join("/");
    }

    public static function isProtected(path:String):Bool {
        return protectedPaths.contains(path);
    }

    static inline var MAX_DEPTH:Int = 64;

    /** True when `child` of `parent` is a symlink (its resolved path leaves the parent's resolved path). */
    static function isLink(parent:String, child:String):Bool {
        try {
            return FileSystem.fullPath(child) != FileSystem.fullPath(parent) + (parent == "/" ? "" : "/") + haxe.io.Path.withoutDirectory(child);
        } catch (e) {
            return true;
        }
    }

    // ---- search ----

    /** Case-insensitive name search below `root`; bounded by result count, visited entries and wall time. */
    public static function search(root:String, query:String, maxResults:Int = 200):Dynamic {
        var needle = query.toLowerCase();
        var results:Array<Dynamic> = [];
        var visited = 0;
        var deadline = Sys.time() + 10;
        var truncated = false;

        function walk(dir:String, depth:Int):Void {
            if (truncated || depth > MAX_DEPTH) return;
            var entries:Array<String>;
            try { entries = FileSystem.readDirectory(dir); } catch (e) { return; }
            for (entry in entries) {
                if (++visited > 200000 || results.length >= maxResults || Sys.time() > deadline) {
                    truncated = true;
                    return;
                }
                var full = (dir == "/" ? "" : dir) + "/" + entry;
                var isDir = false;
                try { isDir = FileSystem.isDirectory(full); } catch (e) {}
                if (entry.toLowerCase().indexOf(needle) != -1)
                    results.push({path: full, name: entry, isDirectory: isDir});
                if (isDir && dir.indexOf("/dev") != 0 && !isLink(dir, full))
                    walk(full, depth + 1);
            }
        }
        walk(root, 0);
        return {results: results, truncated: truncated};
    }

    // ---- copy / move / delete ----

    public static function copy(source:String, destination:String, depth:Int = 0):Void {
        if (depth > MAX_DEPTH)
            throw "Folder nesting too deep";
        if (FileSystem.isDirectory(source)) {
            if (destination == source || destination.startsWith(source + "/"))
                throw "Cannot copy a folder into itself";
            if (!FileSystem.exists(destination)) FileSystem.createDirectory(destination);
            for (entry in FileSystem.readDirectory(source)) {
                if (isLink(source, source + "/" + entry))
                    continue; // symlinks are not followed
                copy(source + "/" + entry, destination + "/" + entry, depth + 1);
            }
        } else {
            var input = File.read(source, true);
            var output = File.write(destination + ".copying", true);
            var buffer = Bytes.alloc(65536);
            try {
                while (true) {
                    var n = input.readBytes(buffer, 0, buffer.length);
                    if (n <= 0) break;
                    output.writeBytes(buffer, 0, n);
                }
            } catch (e:haxe.io.Eof) {}
            input.close();
            output.close();
            FileSystem.rename(destination + ".copying", destination);
        }
    }

    public static function move(source:String, destination:String):Void {
        if (isProtected(source))
            throw "Refusing to move protected path " + source;
        if (FileSystem.exists(destination))
            throw "Destination exists: " + destination;
        try {
            FileSystem.rename(source, destination);
        } catch (e) { // different filesystem: copy then delete
            copy(source, destination);
            remove(source);
        }
    }

    public static function remove(path:String, depth:Int = 0):Void {
        if (isProtected(path))
            throw "Refusing to delete protected path " + path;
        if (depth > MAX_DEPTH)
            throw "Folder nesting too deep";
        if (FileSystem.isDirectory(path)) {
            for (entry in FileSystem.readDirectory(path)) {
                var child = path + "/" + entry;
                if (isLink(path, child)) {
                    // Remove the link itself, never what it points to.
                    try { FileSystem.deleteFile(child); } catch (e) {}
                    continue;
                }
                remove(child, depth + 1);
            }
            FileSystem.deleteDirectory(path);
        } else {
            FileSystem.deleteFile(path);
        }
    }

    // ---- zip ----

    public static function zip(paths:Array<String>, output:String):Void {
        if (FileSystem.exists(output))
            throw "Output exists";
        var entries = new List<haxe.zip.Entry>();
        var total = 0;
        function add(full:String, name:String, depth:Int):Void {
            if (depth > MAX_DEPTH)
                throw "Folder nesting too deep";
            if (FileSystem.isDirectory(full)) {
                for (e in FileSystem.readDirectory(full))
                    if (!isLink(full, full + "/" + e))
                        add(full + "/" + e, name + "/" + e, depth + 1);
                return;
            }
            var size = FileSystem.stat(full).size;
            total += size;
            if (size > MAX_ZIP_FILE || total > MAX_ZIP_TOTAL)
                throw "Too large to zip in memory (limit 64 MB per file, 256 MB total)";
            var data = File.getBytes(full);
            entries.add({
                fileName: name, fileSize: data.length, fileTime: Date.now(), compressed: false,
                dataSize: data.length, data: data, crc32: haxe.crypto.Crc32.make(data), extraFields: null
            });
        }
        for (p in paths)
            add(p, Path.withoutDirectory(p), 0);

        var out = File.write(output + ".tmp", true);
        new haxe.zip.Writer(out).write(entries);
        out.close();
        FileSystem.rename(output + ".tmp", output);
    }

    /** Extracts `archive` into `destination`, skipping any entry that would escape it. Returns the number of files written. */
    public static function unzip(archive:String, destination:String):Int {
        if (FileSystem.stat(archive).size > MAX_ZIP_TOTAL)
            throw "Archive too large to extract in memory (limit 256 MB)";
        var entries = haxe.zip.Reader.readZip(new haxe.io.BytesInput(File.getBytes(archive)));
        if (!FileSystem.exists(destination)) FileSystem.createDirectory(destination);
        var count = 0;
        var total = 0;
        for (entry in entries) {
            var name = entry.fileName;
            if (name.indexOf("..") != -1 || name.startsWith("/") || name.indexOf("\\") != -1)
                continue;
            var target = destination + "/" + name;
            if (name.endsWith("/")) {
                if (!FileSystem.exists(target)) FileSystem.createDirectory(target);
                continue;
            }
            var dir = Path.directory(target);
            if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
            total += entry.fileSize;
            if (entry.fileSize > MAX_ZIP_TOTAL || total > MAX_ZIP_TOTAL)
                throw "Archive expands beyond 256 MB";
            // zip entries are raw deflate; Reader.unzip handles that (Uncompress.run expects a zlib header).
            haxe.zip.Reader.unzip(entry);
            File.saveBytes(target, entry.data);
            count++;
        }
        return count;
    }

    // ---- text / hex ----

    public static function readText(path:String):Dynamic {
        if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
            return {error: "File not found"};
        var size = FileSystem.stat(path).size;
        if (size > MAX_TEXT_SIZE)
            return {error: "File too large for the editor (limit 1 MB)"};
        return {content: File.getContent(path), size: size};
    }

    public static function writeText(path:String, content:String):Void {
        if (FileSystem.exists(path) && FileSystem.isDirectory(path))
            throw "Path is a directory";
        if (content.length > MAX_TEXT_SIZE)
            throw "Content too large (limit 1 MB)";
        File.saveContent(path + ".saving", content);
        FileSystem.rename(path + ".saving", path); // rename(2) replaces the target atomically
    }

    public static function readHex(path:String, offset:Int, length:Int):Dynamic {
        if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
            return {error: "File not found"};
        if (offset < 0 || length < 1 || length > 4096)
            return {error: "length must be 1-4096 and offset >= 0"};
        var size = FileSystem.stat(path).size;
        if (offset >= size)
            return {size: size, offset: offset, hex: "", ascii: ""};
        var count = Std.int(Math.min(length, size - offset));
        var input = File.read(path, true);
        input.seek(offset, SeekBegin);
        var bytes = Bytes.alloc(count);
        input.readFullBytes(bytes, 0, count);
        input.close();
        var ascii = new StringBuf();
        for (i in 0...count) {
            var c = bytes.get(i);
            ascii.addChar(c >= 32 && c < 127 ? c : 46);
        }
        return {size: size, offset: offset, hex: bytes.toHex(), ascii: ascii.toString()};
    }
}
