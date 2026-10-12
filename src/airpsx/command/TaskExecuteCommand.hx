package airpsx.command;
import hx.well.console.AbstractCommand;
import sys.thread.Mutex;
import haxe.io.NullOutput;
import sys.io.File;
import airpsx.utils.RuleScriptUtils;
import airpsx.utils.TypeUtils;
import sys.FileSystem;
import airpsx.type.TaskStatus;
import hx.well.facades.DBStatic;
import haxe.io.Output;
import airpsx.type.DatabaseType;
import airpsx.type.ScriptType;
import airpsx.utils.ScriptUtils;
class TaskExecuteCommand extends AbstractCommand<Bool> {
    public static var taskMutex:Mutex = new Mutex();

    public override function group():String {
        return "task";
    }

    public function signature():String {
        return "execute";
    }

    public function description():String {
        return "execute scheduled tasks";
    }

    public function handle():Bool {
        if(!taskMutex.tryAcquire())
        {
            trace("Task already running.");
            return cast false;
        }
        try {
            trace("execute");
            var db = DBStatic.connection(DatabaseType.TASK);
            var resultSet = db.query('SELECT id, type, script, frequency, logs, lastRun FROM tasks WHERE enabled = 1 and script <> "" and (triggerType = "cron" or triggerType is null)');
            var results = resultSet.results();
            while (results.length > 0)
            {
                var result:Dynamic = results.first();
                results.remove(result);
                var frequency:Int = result.frequency;
                var lastRunDate:Date = Date.fromString(result.lastRun ?? Date.fromTime(0).toString());
                if(lastRunDate.getTime() + ((frequency - 30) * 1000) < Date.now().getTime())
                {
                    airpsx.task.TaskRunner.run(result);
                }
            }
        } catch (e) {
            taskMutex.release();
            throw e;
        }
        taskMutex.release();

        return cast true;
    }
}
