/*
** Petal
** distortion.scd
** Wolf Honore
**
** Distortion algorithm that models guitar distortion pedals.
** Credits: Originally implemented by Scott Petersen.
** Based on the paper "Simplified, Physically-informed Models of Distortion and
** Overdrive Guitar Effects Pedals" by Yeh, Abel, and Smith (CCRMA)
** Presented at the 10h in. conference on digital audio effects, Sept 10-15 2007.
*/

(
var fxName = \distortion;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, gain=3, dist=2.5, tone=0.3|
    // gain [1, 10]: Amplitude multiplier before distortion
    // dist [1, 10]: Amount of distortion
    // tone [-1, 1]: EQ control
    var lowF, midF, hiF;
    var distSig;

    lowF = 120; // LPF cutoff
    midF = 200; // BPF center
    hiF = 380; // HPF cutoff

    // Cascading high-pass filters
    in = HPF.ar(HPF.ar(in, 3), 3);

    // Bandpass filter and add gain
    in = gain * BBandPass.ar(in, midF, 4);

    // Create distortion using diode clipper algorithm and dist parameter
    distSig = (1 + (in.abs * dist)) * dist.reciprocal;
    in = in / distSig;

    // Allow adjustable tone by xfading between low- and high-pass filters
    in = XFade2.ar(LPF.ar(in, lowF), HPF.ar(in, hiF), tone);

    // Prevent signal from clipping
    Limiter.ar(in, 1, 0.01);
});

// Controls
fxName -> [
    \gain -> ControlSpec(1, 10, step: 0.05, default: 3, units: \mult),
    \dist -> ControlSpec(1, 10, step: 0.05, default: 2.5, units: \mult),
    \tone -> ControlSpec(-1, 1, step: 0.05, default: 0.3, units: \pct)
];
)
