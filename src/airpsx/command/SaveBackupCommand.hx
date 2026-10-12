package airpsx.command;
import hx.well.console.AbstractCommand;

class SaveBackupCommand extends AbstractCommand<Bool> {
    public override function group():String {
        return "savebackup";
    }

    public function signature():String {
        return "run";
    }

    public function description():String {
        return "run the scheduled save backup when it is due";
    }

    public function handle():Bool {
        #if orbis
        airpsx.save.SaveBackupManager.tick();
        #end
        return cast true;
    }
}
