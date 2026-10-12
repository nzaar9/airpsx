package airpsx.task;
import sys.thread.Thread;
import hx.well.facades.DBStatic;
import airpsx.type.DatabaseType;

class TaskEvents {
    static var lastTitleID:String = "";
    static var tempActive:Map<Int, Bool> = new Map();
    static var initialized:Bool = false;

    /** Fire all enabled tasks bound to `trigger`. `filter` is matched against triggerValue when the task sets one. */
    public static function fire(trigger:String, ?filter:String, ?extra:Map<String, Any>):Void {
        if (airpsx.utils.MaintenanceUtils.enabled())
            return;
        var db = DBStatic.connection(DatabaseType.TASK);
        var rows:Array<Dynamic> = [];
        var rs = db.query('SELECT id, type, script, logs, triggerValue FROM tasks WHERE enabled = 1 AND script <> "" AND triggerType = ? AND status = 0', trigger);
        while (rs.hasNext())
            rows.push(rs.next());

        for (row in rows) {
            var value:String = row.triggerValue;
            if (filter != null && value != null && value != "" && value != filter)
                continue;
            // Run off the scheduler thread so a long script cannot stall stats logging.
            // Each task gets its own copy: script backends mutate `extra` and tasks run on separate threads.
            var copy:Map<String, Any> = extra == null ? null : [for (k => v in extra) k => v];
            Thread.create(() -> {
                try { TaskRunner.run(row, copy); } catch (e) { trace('event task failed: ${e}'); }
            });
        }
    }

    /** Called once per stats tick (60s) with the current readings. */
    public static function onTick(titleID:String, temperature:Int):Void {
        if (!initialized) {
            // First tick: treat the current state as baseline, don't report a "launch" for an already-running game.
            initialized = true;
            lastTitleID = titleID;
        } else if (titleID != lastTitleID) {
            if (lastTitleID != "")
                airpsx.utils.WebhookUtils.emit("game_close", {titleID: lastTitleID});
            if (titleID != "")
                airpsx.utils.WebhookUtils.emit("game_launch", {titleID: titleID});
            if (lastTitleID != "")
                fire(TaskTrigger.GAME_CLOSE, lastTitleID, ["titleID" => lastTitleID]);
            if (titleID != "")
                fire(TaskTrigger.GAME_LAUNCH, titleID, ["titleID" => titleID]);
            lastTitleID = titleID;
        }

        if (airpsx.utils.MaintenanceUtils.enabled())
            return;

        // temp_above fires once per task on the rising edge and re-arms when the temperature drops below its threshold.
        var db = DBStatic.connection(DatabaseType.TASK);
        var rs = db.query('SELECT id, type, script, logs, triggerValue FROM tasks WHERE enabled = 1 AND script <> "" AND triggerType = ? AND status = 0', TaskTrigger.TEMP_ABOVE);
        var rows:Array<Dynamic> = [];
        while (rs.hasNext())
            rows.push(rs.next());
        var live:Map<Int, Bool> = new Map();
        for (row in rows) live.set(row.id, true);
        for (id in [for (k in tempActive.keys()) k]) // forget deleted/disabled tasks so a re-enabled one can fire again
            if (!live.exists(id)) tempActive.remove(id);
        for (row in rows) {
            var id:Int = row.id;
            var threshold = Std.parseInt(Std.string(row.triggerValue));
            if (threshold == null)
                continue;
            if (temperature >= threshold) {
                if (!tempActive.exists(id)) {
                    tempActive.set(id, true);
                    Thread.create(() -> {
                        try { TaskRunner.run(row, ["temperature" => temperature, "titleID" => titleID]); } catch (e) {}
                    });
                }
            } else {
                tempActive.remove(id);
            }
        }
    }
}
