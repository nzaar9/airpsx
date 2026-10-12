package airpsx.utils;
import hx.well.facades.DBStatic;

class SettingsUtils {
    public static function get(key:String, ?defaultValue:String):String {
        var rs = DBStatic.query('SELECT value FROM settings WHERE key = ?', key);
        return rs.hasNext() ? rs.next().value : defaultValue;
    }

    public static function set(key:String, value:String):Void {
        DBStatic.query('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', key, value);
    }
}
