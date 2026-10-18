package hx.well.pool;
import sys.db.Connection;

/*
 * AirPSX override of hxwell's hx.well.pool.DatabasePool.
 *
 * The only change from upstream is the busy timeout in create(). Without it, two threads writing to the same
 * SQLite file at once make one of them fail immediately with "Database is busy"; a request that dies that way
 * can leave its connection open (hxwell ignores a failed close) with the database still locked.
 * Remove this file when hxwell sets a busy timeout itself.
 */
class DatabasePool extends AbstractPool<Connection> {
    private var key:String;
    private var config:Dynamic;

    public function new(key:String, config:Dynamic) {
        this.key = key;
        this.config = config;

        super();
    }

    public function create():Connection {
        if(this.config.path != null) {
            var connection = sys.db.Sqlite.open(this.config.path);
            // Wait briefly for a competing writer instead of failing at once with "Database is busy".
            // Kept short on purpose: HTTP requests are served by only a few threads.
            var result = connection.request("PRAGMA busy_timeout = 2000");
            while (result.hasNext())
                result.next();
            return connection;
        } else
            return sys.db.Mysql.connect(this.config);
    }

    public function size():Int {
        return 0;
    }

    public override function free(object:Connection):Void {
        #if !php
        mutex.acquire();
        try {
            // Only add the pool elements back.
            if(objects.indexOf(object) == -1)
                object.close();
        } catch (e) {

        }
        mutex.release();

        super.free(object);
        #end
    }
}