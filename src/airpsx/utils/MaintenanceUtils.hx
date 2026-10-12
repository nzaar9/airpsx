package airpsx.utils;

/**
 * Maintenance mode: while on, AirPSX stops starting anything on its own (cron and event tasks,
 * scheduled save backups, queued PKG installs and decrypt jobs) so the console can be worked on safely.
 * Manual actions through the API still work. State is persisted in the settings table.
 */
class MaintenanceUtils {
    public static function enabled():Bool {
        try {
            return SettingsUtils.get("maintenance.enabled", "0") == "1";
        } catch (e) {
            return false;
        }
    }

    public static function set(value:Bool):Void {
        SettingsUtils.set("maintenance.enabled", value ? "1" : "0");
    }
}
