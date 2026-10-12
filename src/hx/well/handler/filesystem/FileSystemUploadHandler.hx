package hx.well.handler.filesystem;

import sys.FileSystem;
import sys.io.File;
import haxe.Int64;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;
import sys.io.FileOutput;
import haxe.Exception;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import airpsx.utils.RequestBodyUtils;
using StringTools;

// POST /api/fs/upload/{path}: single-request upload. The web UI sends the file as multipart/form-data
// (FormData); curl-style clients may send the raw bytes. For large files prefer /api/fs/upload-session/*.
class FileSystemUploadHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        var input:Input = request.context.input;
        var contentLength:Int = Std.parseInt(request.header("Content-Length", "0"));

        // hxwell no longer exposes route parameters through input(), so read it from the route.
        var path:String = request.route("path");
        if (path == null || path == "")
            path = request.input("path");
        if (path == null || path == "" || path.indexOf("..") != -1) {
            RequestBodyUtils.drain(input, contentLength);
            return {success: false, message: "invalid path"};
        }
        if (!path.startsWith("/"))
            path = "/" + path;

        if (FileSystem.exists(path)) {
            RequestBodyUtils.drain(input, contentLength);
            return {success: false, message: "file exists"};
        }

        var consumed = 0;
        var output:FileOutput = null;
        var temp = path + ".temp";
        try {
            output = File.write(temp, true);
            var remaining = contentLength;

            // Browsers wrap the file in a multipart envelope: part headers, the data, then "\r\n--boundary--\r\n".
            var contentType = request.header("Content-Type", "");
            var boundaryAt = contentType.indexOf("boundary=");
            if (contentType.toLowerCase().startsWith("multipart/form-data") && boundaryAt != -1) {
                var boundary = contentType.substr(boundaryAt + 9).split(";")[0].trim();
                if (boundary.startsWith("\"") && boundary.endsWith("\""))
                    boundary = boundary.substr(1, boundary.length - 2);

                var trailer = ("\r\n--" + boundary + "--\r\n").length;
                var headerEnd = "";
                var guard = 0;
                // Skip the part headers (everything up to the first blank line).
                while (!headerEnd.endsWith("\r\n\r\n")) {
                    headerEnd += String.fromCharCode(input.readByte());
                    consumed++;
                    if (++guard > 8192)
                        throw "Malformed multipart body";
                }
                remaining = contentLength - consumed - trailer;
                if (remaining < 0)
                    throw "Malformed multipart body";
                copy(input, output, remaining);
                consumed += remaining;
                // Consume the closing boundary.
                RequestBodyUtils.drain(input, contentLength - consumed);
                consumed = contentLength;
            } else {
                copy(input, output, remaining);
                consumed += remaining;
            }

            output.close();
            output = null;
            FileSystem.rename(temp, path);
        } catch (e:Dynamic) {
            if (output != null) try { output.close(); } catch (_:Dynamic) {}
            try { if (FileSystem.exists(temp)) FileSystem.deleteFile(temp); } catch (_:Dynamic) {}
            RequestBodyUtils.drain(input, contentLength - consumed);
            return {success: false, message: Std.string(e)};
        }

        return {success: true};
    }

    static function copy(input:Input, output:FileOutput, size:Int):Void {
        var buffer = Bytes.alloc(65536);
        var left = size;
        while (left > 0) {
            var n = input.readBytes(buffer, 0, Std.int(Math.min(buffer.length, left)));
            if (n <= 0)
                throw "Connection closed before the upload finished";
            output.writeBytes(buffer, 0, n);
            left -= n;
        }
    }
}
