package cpp.lib;

#if orbis
@:include('time.h')
class LibClock {
    /**
     * Seconds since the console booted (CLOCK_MONOTONIC), unaffected by wall-clock changes.
     * Process start times (ki_start) are wall-clock values recorded at fork time; when the console clock
     * is wrong at boot (or set later by NTP) they no longer line up with the browser's clock, so uptimes
     * are computed from this counter instead.
     */
    public static function monotonicSeconds():Float {
        return untyped __cpp__("([]() -> double { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9; })()");
    }
}
#end
