package hx.well.handler.pkg;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.install.InstallQueueManager;

// POST /api/package/queue/add {source}: http(s) URL, local .pkg, or a directory of .pkg files.
class InstallQueueAddHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "source" => [ValidatorRule.Required, ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var queued = InstallQueueManager.enqueue(request.input("source"));
        if (queued == 0)
            return {error: "Nothing to queue: source is missing, invalid, or has no .pkg files"};
        return {queued: queued};
    }
}
