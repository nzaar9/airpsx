package hx.well.handler.pkg;
import hx.well.handler.AbstractHandler;
import hx.well.http.Request;
import hx.well.http.AbstractResponse;
import hx.well.http.RequestStatic.request;
import hx.well.validator.ValidatorRule;
import airpsx.install.PkgMetadata;
using StringTools;

// POST /api/package/preview {path}: title, version, content/title IDs of a local .pkg.
// iconPath (when present) is a local PNG that can be fetched through /api/fs/download.
class PackagePreviewHandler extends AbstractHandler {
    public override function validate():Bool {
        return request().validate([
            "path" => [ValidatorRule.Required, ValidatorRule.String]
        ]);
    }

    public function execute(request:Request):AbstractResponse {
        var path:String = request.input("path");
        if (path.indexOf("..") != -1 || !path.startsWith("/"))
            return {error: "Invalid path"};
        var info = PkgMetadata.read(path);
        if (info == null)
            return {error: "Not a readable PKG (only local PS4-format packages can be previewed)"};
        return info;
    }
}
