package hx.well.handler.stats;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.facades.DBStatic;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;

// Thermal history, optionally for a single title: GET /api/stats/history?titleID=CUSA00000&limit=500
class StatsHistoryHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "titleID" => [ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        // Query-string values are text, so parse by hand (a ValidatorRule.Int rule would reject "5" with a 422).
        var parsed = Std.parseInt(Std.string(request.input("limit", 500)));
        var limit:Int = parsed == null ? 500 : parsed;
        if (limit < 1) limit = 1;
        if (limit > 1000) limit = 1000;

        var titleID:String = request.input("titleID");
        if (titleID != null && titleID != "") {
            return DBStatic.query('SELECT id, temperature, socSensorTemperature, frequency, titleID, timestamp FROM stats WHERE titleID = ? ORDER BY id DESC LIMIT ?', titleID, limit);
        }
        return DBStatic.query('SELECT id, temperature, socSensorTemperature, frequency, titleID, timestamp FROM stats ORDER BY id DESC LIMIT ?', limit);
    }
}
