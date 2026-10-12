package hx.well.handler.pkg;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.install.InstallQueueManager;

// POST /api/package/queue/cancel {id, retry?:Bool}: cancels a pending entry, or re-queues a failed/cancelled one.
class InstallQueueCancelHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "id" => [ValidatorRule.Required, ValidatorRule.Int],
            "retry" => [ValidatorRule.Bool]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var id:Int = request.input("id");
        var ok = request.input("retry", false) == true ? InstallQueueManager.retry(id) : InstallQueueManager.cancel(id);
        return {success: ok};
    }
}
