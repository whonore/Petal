/*
** OneBox
** reverse.scd
** Wolf Honore
**
** Buffer and reverse incoming signal.
*/

(
var fxName = \reverse;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in|
    var dur, buf, brate, bframe;
    var write, read1, read2;
    var switch, del, env;

    dur = 0.3; // Recording duration
    buf = LocalBuf(44100 * 2 * dur, 2).clear; // Allocate twice as much space
    brate = BufRateScale.kr(buf);
    bframe = BufFrames.kr(buf);

    // Write and read heads. The two read heads are so reading doesn't overlap
    // with writing.
    write = Phasor.ar(0, brate, 0, bframe); // From 0 to end
    read1 = Phasor.ar(0, -1 * brate, bframe / 2, 0, bframe / 2); // From half to 0
    read2 = Phasor.ar(0, -1 * brate, bframe, bframe / 2, bframe); // From end to half

    // Envelope to minimize clicks
    del = 0.05;
    env = EnvGen.ar(Env([0, 1, 1, 0], [del, dur - (2 * del), del]).circle, doneAction: 2);

    // Alternate 0 to 1 every dur seconds
    switch = LFPulse.ar((1 / (2  * dur)));

    // Alternate between reading first and second half
    BufWr.ar(in, buf, write, 0);
    env * Select.ar(switch, [
        BufRd.ar(2, buf, read1, 0, 4),
        BufRd.ar(2, buf, read2, 0, 4)
    ]);
});

fxName -> [];
)
