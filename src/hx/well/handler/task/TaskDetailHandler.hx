package hx.well.handler.task;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.facades.DBStatic;
import airpsx.type.DatabaseType;
import hx.well.validator.ValidatorRule;
import hx.well.http.RequestStatic.request;

class TaskDetailHandler extends AbstractHandler {
    public static var instance:TaskDetailHandler;

    public override function validate():Bool {
        return request().validate([
            "id" => [ValidatorRule.Required, ValidatorRule.Int]
        ]);
    }

    public function new() {
        super();
        instance = this;
    }

    public function execute(request:Request):AbstractResponse {
        var id:Int = request.input("id");

        // select() reads the whole result so no half-read statement keeps the database locked
        var rows = DBStatic.connection(DatabaseType.TASK).select('SELECT * FROM tasks WHERE id = ?', id);
        if(rows.length == 0)
            return {"message": "Task not found"};

        return rows[0];
    }
}