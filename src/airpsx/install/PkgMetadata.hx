package airpsx.install;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import haxe.io.Bytes;

typedef PkgInfo = {
    contentId:String,
    titleId:String,
    ?title:String,
    ?version:String,
    ?iconPath:String
}

/**
 * Best-effort reader for PS4-style PKG headers ("\x7FCNT", big endian) of local files.
 * content_id (0x40) is read directly; title/version/icon come from the entry table, and any
 * failure there just leaves those fields empty. Other PKG formats return null.
 */
class PkgMetadata {
    static inline var ID_PARAM_SFO:Int = 0x1000;
    static inline var ID_ICON0_PNG:Int = 0x1200;
    static inline var MAX_ENTRY_SIZE:Int = 8 * 1024 * 1024;
    public static inline var ICON_PATH:String = '${Const.DATA_PATH}/pkgicons';

    public static function read(path:String):Null<PkgInfo> {
        if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
            return null;

        var input:FileInput = File.read(path, true);
        try {
            input.bigEndian = true;
            if (input.readString(4) != "\x7FCNT") {
                input.close();
                return null;
            }

            input.seek(0x40, SeekBegin);
            var contentId = StringTools.trim(input.readString(36)).split("\x00")[0];
            var info:PkgInfo = {
                contentId: contentId,
                // UP0001-CUSA00000_00-XXXXXXXXXXXXXXXX
                titleId: contentId.length >= 16 ? contentId.substr(7, 9) : ""
            };

            try {
                readEntries(input, info, FileSystem.stat(path).size);
            } catch (e) {
                trace('pkg entry table not readable: ${e}');
            }
            input.close();
            return info;
        } catch (e) {
            input.close();
            return null;
        }
    }

    static function readEntries(input:FileInput, info:PkgInfo, fileSize:Int):Void {
        input.seek(0x10, SeekBegin);
        input.readInt32(); // file count
        var entryCount = input.readInt32();
        input.readUInt16(); // sc entry count
        input.readUInt16();
        var tableOffset = input.readInt32();
        if (entryCount <= 0 || entryCount > 4096 || tableOffset <= 0 || tableOffset + entryCount * 32 > fileSize)
            return;

        for (i in 0...entryCount) {
            input.seek(tableOffset + i * 32, SeekBegin);
            var id = input.readInt32();
            input.readInt32(); // filename offset
            input.readInt32(); // flags1
            input.readInt32(); // flags2
            var offset = input.readInt32();
            var size = input.readInt32();
            if (offset <= 0 || size <= 0 || size > MAX_ENTRY_SIZE || offset + size > fileSize)
                continue;

            if (id == ID_PARAM_SFO || id == ID_ICON0_PNG) {
                input.seek(offset, SeekBegin);
                var data = Bytes.alloc(size);
                input.readBytes(data, 0, size);
                if (id == ID_PARAM_SFO) {
                    parseSfo(data, info);
                } else {
                    if (!FileSystem.exists(ICON_PATH))
                        FileSystem.createDirectory(ICON_PATH);
                    var safeName = ~/[^A-Za-z0-9_\-]/g.replace(info.contentId, "_");
                    var iconFile = '${ICON_PATH}/${safeName}.png';
                    File.saveBytes(iconFile, data);
                    info.iconPath = iconFile;
                }
            }
        }
    }

    // PARAM.SFO is little endian: header (magic, version, keyTable, dataTable, count) + 16-byte index entries.
    static function parseSfo(data:Bytes, info:PkgInfo):Void {
        if (data.length < 20 || data.getInt32(0) != 0x46535000) // "\0PSF"
            return;
        var keyTable = data.getInt32(8);
        var dataTable = data.getInt32(12);
        var count = data.getInt32(16);
        if (count < 0 || 20 + count * 16 > data.length)
            return;

        for (i in 0...count) {
            var e = 20 + i * 16;
            var keyOffset = keyTable + data.getUInt16(e);
            var dataOffset = dataTable + data.getInt32(e + 12);
            if (keyOffset >= data.length || dataOffset >= data.length)
                continue;
            var key = readCString(data, keyOffset);
            if (key == "TITLE")
                info.title = readCString(data, dataOffset);
            else if (key == "APP_VER" || (key == "VERSION" && info.version == null))
                info.version = readCString(data, dataOffset);
        }
    }

    static function readCString(data:Bytes, start:Int):String {
        var end = start;
        while (end < data.length && data.get(end) != 0)
            end++;
        return data.getString(start, end - start);
    }
}
