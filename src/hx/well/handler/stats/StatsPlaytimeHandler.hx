package hx.well.handler.stats;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.facades.DBStatic;

// Cumulative playtime per title in seconds, most recently played first.
class StatsPlaytimeHandler extends AbstractHandler {
    public function execute(request:Request):AbstractResponse {
        return DBStatic.query('SELECT titleID, seconds, lastPlayed FROM playtime ORDER BY lastPlayed DESC');
    }
}
