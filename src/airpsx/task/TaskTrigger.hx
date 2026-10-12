package airpsx.task;

/** Trigger kinds a task can use. Stored in tasks.triggerType; tasks.triggerValue holds the parameter. */
class TaskTrigger {
    public static inline var CRON:String = "cron";                // periodic, tasks.frequency seconds
    public static inline var BOOT:String = "boot";                // once, when AirPSX starts
    public static inline var GAME_LAUNCH:String = "game_launch";  // triggerValue: optional titleID filter
    public static inline var GAME_CLOSE:String = "game_close";    // triggerValue: optional titleID filter
    public static inline var TEMP_ABOVE:String = "temp_above";    // triggerValue: CPU temperature threshold

    public static var all:Array<String> = [CRON, BOOT, GAME_LAUNCH, GAME_CLOSE, TEMP_ABOVE];
    // "on USB insert" is not implemented: it needs a mount-change source that is not exposed yet.
}
