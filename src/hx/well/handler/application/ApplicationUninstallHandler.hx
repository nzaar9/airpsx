package hx.well.handler.application;

#if orbis
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import cpp.lib.LibSceAppInstUtil;
import cpp.lib.Process;

// POST /api/app/uninstall/{titleId}: uninstalls a title. Refused while that title is running.
class ApplicationUninstallHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        var titleId:String = request.route("titleId");
        var running = Process.getRunningApp();
        if (running != null && running.titleID == titleId)
            return {success: false, message: "Close the application first"};

        var result:Int = LibSceAppInstUtil.appInstUtilAppUnInstall(titleId);
        return result == 0 ? {success: true} : {success: false, message: "Uninstall failed", code: result};
    }
}
#end
