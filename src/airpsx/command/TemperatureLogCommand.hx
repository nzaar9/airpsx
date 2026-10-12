package airpsx.command;
import hx.well.console.AbstractCommand;
import hx.well.facades.DBStatic;
import airpsx.task.TaskEvents;
import airpsx.utils.SettingsUtils;
import airpsx.utils.WebhookUtils;
#if orbis
import cpp.lib.LibKernel;
import cpp.lib.Process;
#end

class TemperatureLogCommand extends AbstractCommand<Bool> {
    public override function group():String {
        return "temperature";
    }

    public function signature():String {
        return "log";
    }

    public function description():String {
        return "log temperature";
    }

    public function handle():Bool {
        #if orbis
        var socSensorTemperature:Int = LibKernel.getSocSensorTemperature();
        var temperature:Int = LibKernel.cpuTemperature;
        var frequency = LibKernel.cpuFrequency;

        var runningApp = Process.getRunningApp();
        var titleID = runningApp != null ? runningApp.titleID : "";

        trace('socSensorTemperature: ${socSensorTemperature}');
        trace('temperature: ${temperature}');
        trace('frequency: ${frequency}');
        trace('titleID: ${titleID}');

        DBStatic.query('INSERT INTO stats (socSensorTemperature, temperature, frequency, titleID) VALUES (?, ?, ?, ?);', socSensorTemperature, temperature, frequency, titleID);

        if (titleID != "") {
            // The logger ticks every 60 seconds, so each tick with a running title adds 60s of playtime.
            DBStatic.query('INSERT INTO playtime (titleID, seconds, lastPlayed) VALUES (?, 60, datetime(\'now\',\'localtime\')) ON CONFLICT(titleID) DO UPDATE SET seconds = seconds + 60, lastPlayed = datetime(\'now\',\'localtime\')', titleID);
        }

        checkOverheat(temperature, titleID);

        try {
            TaskEvents.onTick(titleID, temperature);
        } catch (e) {
            trace('task events failed: ${e}');
        }
        #end

        return cast true;
    }

    static var lastAlert:Float = 0;

    // Webhook alert when the CPU temperature reaches `alert.temperature`; at most one alert per 10 minutes.
    static function checkOverheat(temperature:Int, titleID:String):Void {
        var threshold = Std.parseInt(SettingsUtils.get("alert.temperature", ""));
        var url = SettingsUtils.get("alert.webhook", "");
        if (threshold == null || url == "" || temperature < threshold)
            return;

        var now = Sys.time();
        if (now - lastAlert < 600)
            return;
        lastAlert = now;

        WebhookUtils.send(url, 'AirPSX: CPU temperature ${temperature}°C (limit ${threshold}°C)' + (titleID != "" ? ' while running ${titleID}' : ''), {temperature: temperature, titleID: titleID});
    }
}
