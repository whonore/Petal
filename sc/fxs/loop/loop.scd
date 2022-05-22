/*
** Petal
** loop.scd
** Wolf Honore
**
** Amplitude triggered looper with adjustable playback rate.
*/

(
var fxName = \loop;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, mix=0.3, dur=0.5, thresh=0.3, rate=1|
    // mix [0, 1]: Dry/wet balance
    // dur [0, 3]: Duration of loop
    // thresh [0, 1]: Amplitude threshold to begin recording
    // rate [0.5, 2]: Playback rate
    var maxdur, buf;
    var amp, on, read, loop;

    maxdur = 3; // Maximum recording duration
    buf = LocalBuf(44100 * maxdur, 2).clear;

    amp = In.ar(~ampBus);
    on = Trig1.ar(amp >= thresh, dur);

    // Read head with adjustable rate and length
    read = Phasor.ar(0, rate * BufRateScale.kr(buf), 0, (dur / maxdur) * BufFrames.kr(buf));

    // Reset and record when amp >= thresh
    RecordBuf.ar(in, buf, run: on, loop: 0, trigger: on);
    loop = BufRd.ar(2, buf, read, 1);

    // Mix dry and wet
    (in * (1 - mix)) + (loop * mix);
});

fxName -> (
    name: "Looper",
    desc: "Loops anything above the amplitude cutoff with an adjustable playback rate.",
    ctrls: [
        \mix -> ControlSpec(0, 1, step: 0.01, default: 0.2, units: \pct),
        \dur -> ControlSpec(0.1, 3, step: 0.01, default: 0.5, units: \sec),
        \thresh -> ControlSpec(0, 1, step: 0.01, default: 0.4, units: \pct),
        \rate -> ControlSpec(0.5, 2, step: 0.1, default: 1, units: \mult)
    ]
);
)
