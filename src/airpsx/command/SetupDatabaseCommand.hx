package airpsx.command;

import cpp.lib.LibKernel;
import airpsx.type.TaskStatus;
import airpsx.Const;
import hx.well.console.AbstractCommand;

class SetupDatabaseCommand extends AbstractCommand<Bool> {
    public function new() {
        super();
    }

    public function signature():String {
        return null;
    }

    public function description():String {
        return null;
    }

    public function handle():Bool {
        var db = sys.db.Sqlite.open(Const.DB_PATH);

        // Create stats table if not exists
        db.request("CREATE TABLE IF NOT EXISTS stats (id INTEGER PRIMARY KEY AUTOINCREMENT, socSensorTemperature INTEGER, temperature INTEGER, frequency REAL, titleID TEXT, timestamp DATE DEFAULT (datetime('now','localtime')));");

        // Create index for stats table
        db.request("CREATE INDEX IF NOT EXISTS idx_titleID ON stats(titleID);");
        db.request("CREATE INDEX IF NOT EXISTS idx_timestamp ON stats(timestamp);");

        // Keep last 1000 stats
        db.request("DELETE FROM stats WHERE id NOT IN (SELECT id FROM stats ORDER BY id DESC LIMIT 1000);");

        // Cumulative playtime per title, incremented by the stats logger
        db.request("CREATE TABLE IF NOT EXISTS playtime (titleID TEXT PRIMARY KEY, seconds INTEGER DEFAULT 0, lastPlayed DATE);");

        // Key/value settings (alert webhook, thresholds)
        db.request("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT);");

        // SELF decrypt jobs; status survives restarts so interrupted jobs can resume
        db.request("CREATE TABLE IF NOT EXISTS decrypt_jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT, output TEXT, status TEXT DEFAULT 'pending', error TEXT, createdAt DATE DEFAULT (datetime('now','localtime')), updatedAt DATE);");
        db.request("UPDATE decrypt_jobs SET status = 'pending' WHERE status = 'running';");
        db.close();


        db = sys.db.Sqlite.open(Const.TASK_DB_PATH);

        // Create schedules table if not exists
        db.request('CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, script TEXT DEFAULT "", logs BOOL DEFAULT TRUE, frequency INT DEFAULT 3600, status INTEGER DEFAULT 0, lastRun DATE, enabled BOOL DEFAULT TRUE, success INTEGER DEFAULT 0, failed INTEGER DEFAULT 0, createdAt DATE DEFAULT (datetime(\'now\',\'localtime\')));');

        // Create type column
        try { db.request('ALTER TABLE tasks ADD COLUMN type TEXT DEFAULT "rulescript";'); } catch (e) {}

        // Event triggers (see airpsx.task.TaskTrigger)
        try { db.request('ALTER TABLE tasks ADD COLUMN triggerType TEXT DEFAULT "cron";'); } catch (e) {}
        try { db.request('ALTER TABLE tasks ADD COLUMN triggerValue TEXT DEFAULT "";'); } catch (e) {}

        var runningSchedules = db.request('SELECT name FROM tasks WHERE status = ${TaskStatus.RUNNING} and enabled = 1');
        for(result in runningSchedules.results())
        {
            LibKernel.sendNotificationRequest('${result.name} task has been disabled due to unexpected status');
        }
        db.request('UPDATE tasks SET enabled = 0, status = ${TaskStatus.IDLE} WHERE status = ${TaskStatus.RUNNING}');
        db.close();
        return cast true;
    }
}
