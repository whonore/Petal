/*
** Petal
** octaver.scd
** Wolf Honore
**
** Octaver that uses RM to create a signal with the fundamental halved and
** containing only the odd partials. Mix in the original signal to recover the
** missing partials.
*/

(
var fxName = \octaver;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in|
    var freq;

    freq = In.kr(~pitchBus);

    // Create sidebands at +/-(f / 2), which results in the
    // harmonic series [f/2, 3f/2, 5f/2, ...]
    (in + (in * SinOsc.ar(freq / 2))) / 2;
});

fxName -> (
    name: "Octaver",
    desc: "Doubles the pitch an octave lower.",
    ctrls: []
);
)
