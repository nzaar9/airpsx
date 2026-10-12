package airpsx.utils;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;

/** Counts the bytes read through it, so a handler that bails out early knows how much body is still unread. */
class CountingInput extends Input {
    var source:Input;
    public var count:Int = 0;

    public function new(source:Input) {
        this.source = source;
    }

    override public function readByte():Int {
        var b = source.readByte();
        count++;
        return b;
    }

    override public function readBytes(s:Bytes, pos:Int, len:Int):Int {
        var n = source.readBytes(s, pos, len);
        count += n;
        return n;
    }
}

class RequestBodyUtils {
    /**
     * Reads and discards `remaining` bytes of the request body. Handlers that answer before reading the whole
     * body must do this: closing a socket with unread request data resets the connection, and the browser then
     * reports a bare "Network error" instead of the response.
     */
    public static function drain(input:Input, remaining:Int):Void {
        if (remaining <= 0)
            return;
        var buffer = Bytes.alloc(16384);
        try {
            while (remaining > 0) {
                var n = input.readBytes(buffer, 0, Std.int(Math.min(buffer.length, remaining)));
                if (n <= 0)
                    break;
                remaining -= n;
            }
        } catch (e:Eof) {} catch (e:Dynamic) {}
    }
}
