/*
** Petal
** conVerb.scd
** Wolf Honore
**
** Convolution reverb using an IR from a church.
*/

(
var fxName = \conVerb;

"../../common.scd".loadRelative(true);

{
    // IR Init
    var buf, bufsize;
    var irChurch;
    var fftsize = 2048;

    // Read IR data
    buf = Buffer.read(~serv, "church.wav".resolveRelative);
    ~serv.sync;

    // Prepare buffer
    bufsize = PartConv.calcBufSize(fftsize, buf);
    irChurch = Buffer.alloc(~serv, bufsize, 1);
    irChurch.preparePartConv(buf, fftsize);
    ~serv.sync;

    // Free IR data
    buf.free;
    ~serv.sync;

    ~makeFx.value(\conVerb, {|in|
        PartConv.ar(in, fftsize, irChurch) / 4;
    });
}.fork;

fxName -> (
    name: "ConvVerb",
    desc: "Simulates the reverb of a church.",
    ctrls: []
);
)
