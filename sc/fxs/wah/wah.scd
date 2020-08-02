/*
** Petal
** wah.scd
** Wolf Honore
**
** An auto-wah using a resonant low-pass filter with a modulating cutoff.
*/

(
var fxName = \wah;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, speed=2, q=2|
    // speed [0, 20]: LFO rate
    // q [1, 5]: Q of resonant filter
    RLPF.ar(in, SinOsc.ar(speed).range(200, 2000), q.reciprocal);
});

fxName -> [
    \speed -> ControlSpec(0, 20, step: 0.1, default: 2),
    \q -> ControlSpec(1, 5, step: 0.1, default: 2)
];
)
