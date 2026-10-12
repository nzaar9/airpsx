package hx.well.handler;
import sys.net.Socket;
import cpp.lib.Process;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
#if orbis
import cpp.lib.LibClock;
#end

// WIP
class ProcessListHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        #if orbis
        var processes = Process.getProcessList();
        if (processes == null)
            return [];

        // Uptime from the monotonic clock, relative to the kernel process (which starts at boot). Start times
        // can be skewed against the browser's clock, but they are consistent with each other.
        var bootUptime = LibClock.monotonicSeconds();
        var kernelStart:Null<Float> = null;
        for (proc in processes) {
            if (proc.pid == 0 || proc.comm == "kernel") {
                kernelStart = proc.start;
                break;
            }
        }

        var rows:Array<Dynamic> = [];
        for (proc in processes) {
            var row:Dynamic = {};
            for (field in Reflect.fields(proc))
                Reflect.setField(row, field, Reflect.field(proc, field));

            // Kernel threads have no emulation name; the UI would print "null".
            var emul:String = proc.emul;
            row.emul = (emul == null || emul == "" || emul == "null") ? "-" : emul;

            if (kernelStart != null) {
                var uptime = bootUptime - (proc.start - kernelStart);
                row.uptime = uptime < 0 ? 0 : Std.int(uptime);
            }
            rows.push(row);
        }
        return rows;
        #else
        return {};
        #end
    }
}
