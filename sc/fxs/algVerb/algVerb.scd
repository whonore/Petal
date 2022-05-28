/*
** Petal
** algVerb.scd
** Wolf Honore
**
** Simulate reverb using comb and allpass filters.
*/

(
var fxName = \algVerb;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, mix=0.33, size=0.5|
    // mix [0, 1]: Dry/wet balance
    // size [0, 1]: Size of the room
    var verb, predel;
    var ncomb, maxdel, combdel, combdec;
    var nall, alldel, alldec;

    // Compute predelay from size
    predel = size.lincurve(0, 1, 0, 0.55, -2); // [0, 0.55]

    ncomb = 6; // Number of comb filters
    maxdel = 0.1; // Maximum delay for comb filters

    // Compute comb filter delay and decay from size
    combdel = size.lincurve(0, 1, 0, maxdel, 1); // [0, maxdel]
    combdec = size.lincurve(0, 1, 0, 10, 2); // [0, 10]

    nall = 4; // Number of comb filters

    // Compute allpass filter delay and decay
    alldel = combdel * Rand(0.97, 1.03); // [97% combdel, 103% combdel]
    alldec = combdec * Rand(0.47, 0.53); // [47% comdec, 53% combdec]

    // Delayed signal
    verb = DelayC.ar(in, 0.1, predel);

    // Send through comb filters in parallel
    verb = Mix.fill(ncomb, {
        CombC.ar(verb, maxdel, combdel * Rand(0.95, 1), combdec);
    });

    // Send through allpass filters in sequence
    nall.do {
        verb = AllpassC.ar(verb, maxdel * 1.03, alldel * Rand(0.95, 1), alldec);
    };

    // Scale down reverb
    verb = verb / ((ncomb + nall) * 2);

    // Mix dry and wet
    (in * (1 - mix)) + (verb * mix);
});

fxName -> (
    name: "AlgoVerb",
    desc: "Simulates reverb using comb and allpass filters.",
    ctrls: [
        \mix -> (
            name: "Mix (Wet/Dry)",
            spec: ControlSpec(0, 1, step: 0.01, default: 0.33, units: \pct)
        ),
        \size -> (
            name: "Room Size",
            spec: ControlSpec(0, 1, step: 0.01, default: 0.5, units: \pct)
        )
    ]
);
)
