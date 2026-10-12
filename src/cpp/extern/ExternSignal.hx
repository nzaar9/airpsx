package cpp.extern;

#if orbis
import cpp.PidT;
import cpp.Int32;

@:keep
@:include('signal.h')
extern class ExternSignal {
    @:native('kill')
    public static function kill(pid:PidT, sig:Int32):Int32;
}
#end
