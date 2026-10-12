package airpsx.decrypt;

/** Default backend: no decryption primitive is wired in, so jobs fail fast with a clear message. */
class UnsupportedSelfBackend implements SelfDecryptBackend {
    public function new() {}
    public function name():String return "none";
    public function supported():Bool return false;
    public function decrypt(source:String, destination:String):Void {
        throw "No SELF decrypt backend is installed in this build";
    }
}
