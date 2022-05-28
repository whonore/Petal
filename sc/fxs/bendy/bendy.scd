/*
** Petal
** bendy.scd
** Wolf Honore
**
** Bend and wobble the pitch. Wobble is basically vibrato and bend
** exponentially increases the pitch.
*/

(
var fxName = \bendy;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, wobbleRate=3, bendDur=1, wobble=0.05, bend=2|
    // wobbleRate [0.01, 10]: LFO speed
    // bendDur [0.1, 5]: Duration of bend
    // wobble [0, 0.1]: Magnitude of wobble
    // bend [0, 10]: Magnitude of bend
    var chain, wobbled, bent, bendEnv, ampEnv;

    // Envelopes for the bend amount and bend amplitude. Amplitude decreases as
    // bend increases.
    bendEnv = EnvGen.ar(Env([1, 1 + bend, 1], [bendDur - 0.05, 0.05], [\exp, \exp]).circle, doneAction: 2);
    ampEnv = EnvGen.ar(Env([0, 1, 0], [0.05, bendDur - 0.05], [0, \sin]).circle, doneAction: 2);

    // FFT and PV to shift the pitch.
    chain = FFT({ LocalBuf(2048) } ! 2, in);
    wobbled = PV_BinShift(chain, 1 + SinOsc.ar(wobbleRate, mul: wobble));
    bent = PV_BinShift(chain, bendEnv);
    wobbled = IFFT(wobbled);
    bent = ampEnv * IFFT(bent);

    // Mix evenly with compensation for bend's changing amplitude.
    (wobbled + bent) / (1 + ampEnv);
});

fxName -> (
    name: "Bendy",
    desc: "Bends and wobbles the pitch.",
    ctrls: [
        \wobbleRate -> (
            name: "Wobble Rate",
            spec: ControlSpec(0.01, 10, step: 0.1, default: 3, units: \hz)
        ),
        \bendDur -> (
            name: "Bend Duration",
            spec: ControlSpec(0.1, 5, step: 0.1, default: 1, units: \sec)
        ),
        \wobble -> (
            name: "Wobble Amount",
            spec: ControlSpec(0, 0.1, step: 0.01, default: 0.05, units: \mult)
        ),
        \bend -> (
            name: "Bend Amount",
            spec: ControlSpec(0, 10, step: 0.5, default: 2, units: \mult)
        )
    ]
);
)
