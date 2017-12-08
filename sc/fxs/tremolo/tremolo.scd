/*
** OneBox
** tremolo.scd
** Wolf Honore
*/

(
var fxName = \tremolo;

"../../common.scd".loadRelative(true);

// Fluctuate maximum amplitude between [1 - depth, 1].
~makeFx.value(fxName, {|in, speed=7, depth=1|
    // speed [1, 10]: LFO rate
    // depth [0, 1]: LFO multiplier
    in * SinOsc.ar(speed).range(1 - depth, 1);
});

fxName -> [
    \speed -> ControlSpec(1, 10, step: 0.1, default: 7),
    \depth -> ControlSpec(0, 1, step: 0.05, default: 1)
];
)
