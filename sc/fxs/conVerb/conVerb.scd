/*
** OneBox
** conVerb.scd
** Wolf Honore
*/

(
var fxName = \conVerb;

"../../common.scd".loadRelative(true);

{
    // IR Init
    var buf, bufsize;
    var irChurch;

    // Read IR data
    buf = Buffer.read(~serv, "church.wav".resolveRelative);
    ~serv.sync;

    // Prepare buffer
    bufsize = PartConv.calcBufSize(2048, buf);
    irChurch = Buffer.alloc(~serv, bufsize, 1);
    irChurch.preparePartConv(buf, 2048);
    ~serv.sync;

    // Free IR data
    buf.free;
    ~serv.sync;

    // Convolution reverb using IR from a church
    ~makeFx.value(\conVerb, {|in|
        PartConv.ar(in, 2048, irChurch) / 4;
    });
}.fork;

fxName -> [];
)
