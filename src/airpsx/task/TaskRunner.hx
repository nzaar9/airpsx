package airpsx.task;
import haxe.io.Output;
import haxe.io.NullOutput;
import sys.io.File;
import sys.FileSystem;
import hx.well.facades.DBStatic;
import airpsx.type.DatabaseType;
import airpsx.type.TaskStatus;
import airpsx.type.ScriptType;
import airpsx.utils.ScriptUtils;
import airpsx.utils.TypeUtils;

class TaskRunner {
    /**
     * Runs a single task row ({id, type, script, logs, ...}) and updates its status/counters.
     * `extra` is passed to the script backend (used by event triggers to expose event data).
     */
    public static function run(row:Dynamic, ?extra:Map<String, Any>):Bool {
        var db = DBStatic.connection(DatabaseType.TASK);
        var id:Int = row.id;
        trace('execute task ${id}');

        db.query('UPDATE tasks SET status = ? WHERE id = ?', TaskStatus.RUNNING, id);

        var script:String = row.script;
        var type:ScriptType = row.type;

        var filePath:String = '${Const.DATA_PATH}/task/';
        if(!FileSystem.exists(filePath))
            FileSystem.createDirectory(filePath);

        var output:Output = TypeUtils.parseBool(row.logs) ? File.append('${filePath}/${id}.log') : new NullOutput();

        var started:Float = haxe.Timer.stamp();
        output.writeString('[${Date.now()}] execute start\n');
        var result:Dynamic = null;
        try {
            result = ScriptUtils.execute(script, type, output, extra);
        } catch (e) {
            output.writeString('[${Date.now()}] error: ${e}\n');
        }
        var isSuccess:Bool = TypeUtils.parseBool(result);
        var increaseKey:String = isSuccess ? "success" : "failed";

        db.query('UPDATE tasks SET status = ?, lastRun = datetime(\'now\',\'localtime\'), ${increaseKey} = ${increaseKey} + 1 WHERE id = ?', TaskStatus.IDLE, id);
        output.writeString('[${Date.now()}] execution ${increaseKey}, took ${haxe.Timer.stamp() - started}s\n');
        output.close();
        return isSuccess;
    }
}
