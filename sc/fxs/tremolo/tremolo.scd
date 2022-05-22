/*
** Petal
** tremolo.scd
** Wolf Honore
**
** Fluctuate maximum amplitude between [1 - depth, 1].
*/

(
var fxName = \tremolo;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, speed=7, depth=1|
    // speed [1, 10]: LFO rate
    // depth [0, 1]: LFO multiplier
    in * SinOsc.ar(speed).range(1 - depth, 1);
});

fxName -> [
    \speed -> ControlSpec(1, 10, step: 0.1, default: 7, units: \hz),
    \depth -> ControlSpec(0, 1, step: 0.05, default: 1, units: \pct)
];
)
