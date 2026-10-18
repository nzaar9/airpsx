package airpsx.utils;
import hx.well.facades.DBStatic;

/**
 * Helpers that always read a query's whole result.
 *
 * A half-read SQLite result keeps its statement (and a read lock on the database file) open until the garbage
 * collector finalizes it. With several threads and connections that shows up as "Database is busy" errors
 * and, worse, as a lock that never goes away when the connection cannot be closed.
 */
class DbUtils {
    /** First row of the query, or null. */
    public static function first(sql:String, ...params:Dynamic):Dynamic {
        var rows:Array<Dynamic> = DBStatic.select(sql, ...params);
        return rows.length > 0 ? rows[0] : null;
    }

    public static function exists(sql:String, ...params:Dynamic):Bool {
        return first(sql, ...params) != null;
    }
}
