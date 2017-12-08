/*
** OneBox
** radio.scd
** Wolf Honore
*/

(
var fxName = \radio;

"../../common.scd".loadRelative(true);

// Simulates an old radio by downsampling, filtering, compressing, and adding noise.
~makeFx.value(fxName, {|in, noiseAmp=0.05, noiseRate=100, minFreq=700, maxFreq=2000|
    // noiseAmp [0, 0.4]: Amplitude of pops
    // noiseRate [50, 300]: Rate of pops
    // minFreq [500, 1000]: HPF cutoff frequency
    // maxFreq [1500, 2200]: LPF cutoff frequency
    var sampleRate, bitDepth;
    var noise;

    sampleRate = 8000;
    bitDepth = 12;

    in = Latch.ar(in, Impulse.ar(sampleRate)); // Downsample
    in = in.round(0.5 ** bitDepth); // Decrease bit depth

    // Add sporadic pops
    noise = Dust.ar(noiseRate) * PinkNoise.ar(noiseAmp);
    in = in + noise;

    // Filter agressively
    in = LPF.ar(HPF.ar(in, minFreq), maxFreq);

    // Amplify low levels
    Compander.ar(in, in, 0.1, 0.8, 1, 0.01, 0.01);
});

fxName -> [
    \noiseAmp -> ControlSpec(0, 0.4, step: 0.01, default: 0.05),
    \noiseRate -> ControlSpec(50, 300, step: 1, default: 100),
    \minFreq -> ControlSpec(500, 1000, step: 1, default: 700),
    \maxFreq -> ControlSpec(1500, 2200, step: 1, default: 2000)
];
)
