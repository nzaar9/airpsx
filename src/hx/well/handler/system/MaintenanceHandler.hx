package hx.well.handler.system;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.utils.MaintenanceUtils;

// POST /api/system/maintenance {enabled?:Bool}: toggles maintenance mode; without a field it just reports the state.
class MaintenanceHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "enabled" => [ValidatorRule.Bool]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var enabled:Dynamic = request.input("enabled");
        if (enabled != null) {
            MaintenanceUtils.set(enabled == true);
            if (enabled != true) {
                // Queue workers stop picking up jobs in maintenance mode; restart them for anything left pending.
                airpsx.install.InstallQueueManager.resume();
                airpsx.decrypt.SelfDecryptManager.resume();
            }
        }
        return {enabled: MaintenanceUtils.enabled()};
    }
}
