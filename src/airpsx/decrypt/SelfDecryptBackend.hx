package airpsx.decrypt;

/**
 * Native SELF -> ELF decryption. Implementations typically wrap a C/C++ library through a Haxe extern
 * (like the other cpp.lib.* bindings) and need kernel read/write primitives, so they are firmware specific.
 */
interface SelfDecryptBackend {
    /** Short description of the firmware/support state, shown in the UI. */
    function name():String;
    function supported():Bool;
    /** Decrypt `source` into the plaintext ELF `destination`. Throw with a readable message on failure. */
    function decrypt(source:String, destination:String):Void;
}
