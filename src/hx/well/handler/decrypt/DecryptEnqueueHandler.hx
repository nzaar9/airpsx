package hx.well.handler.decrypt;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.decrypt.SelfDecryptManager;

// POST /api/decrypt/enqueue {path}: file, or a directory to queue recursively (eboot.bin, .sprx, .elf, ...).
class DecryptEnqueueHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "path" => [ValidatorRule.Required, ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var queued = SelfDecryptManager.enqueue(request.input("path"));
        if (queued == 0)
            return {error: "Nothing to queue: path is missing, invalid, or has no SELF candidates"};
        return {queued: queued, backend: SelfDecryptManager.backend.name(), supported: SelfDecryptManager.backend.supported()};
    }
}
