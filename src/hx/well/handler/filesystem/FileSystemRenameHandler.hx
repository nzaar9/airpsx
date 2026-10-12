package hx.well.handler.filesystem;
import sys.FileSystem;
import haxe.io.Path;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.fs.FileOps;
using StringTools;

// POST /api/fs/rename {path, name}: renames a file or folder inside its current directory (name is a bare name, not a path).
class FileSystemRenameHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "path" => [ValidatorRule.Required, ValidatorRule.String],
            "name" => [ValidatorRule.Required, ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var path = FileOps.normalize(request.input("path"));
        var name:String = request.input("name");
        if (path == null || !FileSystem.exists(path))
            return {success: false, message: "path not found"};
        if (FileOps.isProtected(path))
            return {success: false, message: "Refusing to rename protected path " + path};
        if (name == "" || name == "." || name.indexOf("/") != -1 || name.indexOf("\\") != -1 || name.indexOf("\x00") != -1)
            return {success: false, message: "invalid name"};

        var target = Path.directory(path) + "/" + name;
        if (FileSystem.exists(target))
            return {success: false, message: "a file with that name already exists"};

        try {
            FileSystem.rename(path, target);
        } catch (e) {
            return {success: false, message: Std.string(e)};
        }
        return {success: true};
    }
}
