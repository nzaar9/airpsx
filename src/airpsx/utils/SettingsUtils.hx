package airpsx.utils;
import hx.well.facades.DBStatic;

class SettingsUtils {
    public static function get(key:String, ?defaultValue:String):String {
        var row:Dynamic = DbUtils.first('SELECT value FROM settings WHERE key = ?', key);
        return row != null ? row.value : defaultValue;
    }

    public static function set(key:String, value:String):Void {
        DBStatic.query('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', key, value);
    }
}
