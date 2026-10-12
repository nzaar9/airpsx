package hx.well.handler.decrypt;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.decrypt.SelfDecryptManager;

class DecryptCancelHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "id" => [ValidatorRule.Required, ValidatorRule.Int]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        return {success: SelfDecryptManager.cancel(request.input("id"))};
    }
}
