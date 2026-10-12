package hx.well.handler;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
#if orbis
import cpp.lib.Process;
import cpp.extern.ExternSignal;
#end

// POST /api/process/kill {pid, force?}: SIGTERM, or SIGKILL with force. Only pids from the live process list,
// never AirPSX itself or the kernel/init (pid <= 1).
class ProcessKillHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "pid" => [ValidatorRule.Required, ValidatorRule.Int],
            "force" => [ValidatorRule.Bool]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        #if orbis
        var pid:Int = request.input("pid");
        if (pid <= 1)
            return {error: "Refusing to signal pid " + pid};
        if (pid == Process.currentProcess().pid)
            return {error: "Refusing to kill AirPSX itself (use /api/server/kill)"};

        var found = false;
        for (proc in Process.getProcessList())
            if (proc.pid == pid) { found = true; break; }
        if (!found)
            return {error: "Process not found"};

        var force = request.input("force", false) == true;
        var result:Int = ExternSignal.kill(pid, force ? 9 : 15);
        return result == 0 ? {success: true} : {error: "kill failed", code: result};
        #else
        return {error: "Only available on the console"};
        #end
    }
}
