/*
** Petal
** chorus.scd
** Wolf Honore
**
** Create slightly out-of-phase copies of the signal by delaying by a
** modulating amount.
*/

(
var fxName = \chorus;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, speed=0.05, depth=0.05|
    // speed [0, 0.15]: LFO rate
    // depth [0, 0.2]: LFO multiplier
    var mods, nmods, spread;

    nmods = 6; // Number of voices
    spread = 0.02; // Maximum percent deviation

    // Create oscillators with slightly offset frequencies and amplitudes,
    // and randomized phases
    mods = Array.fill(nmods, {|idx|
        var mod;

        mod = SinOsc.ar(speed * Rand(1 - spread, 1 + spread), Rand(0, 2pi)).unipolar;
        mod = mod * depth * Rand(1 - spread, 1);
    });
    mods = Mix(DelayC.ar(in, 1, mods)) / nmods;

    (in + mods) / 2;
});

fxName -> [
    \speed -> ControlSpec(0, 0.15, step: 0.01, default: 0.05, units: \hz),
    \depth -> ControlSpec(0, 0.2, step: 0.01, default: 0.05, units: \mult)
];
)
