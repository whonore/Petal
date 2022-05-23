/*
** Petal
** common.scd
** Wolf Honore
**
** Functions used in multiple files.
*/

// Only execute once
~common_loaded ?? {
    ~serv = Server.default;

    // Control Busses
    ~pitchBus = Bus.control(~serv, 2);
    ~ampBus = Bus.audio(~serv, 2);

    // Factory function to produce effect SynthDefs.
    ~makeFx = {|name, func, lags|
        SynthDef(name, {|out=0, xfade=1, gate=1|
            var in, env, snd;

            // Wrap in a sustaining envelope so the effect can be released gracefully
            in = In.ar(out, 2);
            env = Linen.kr(gate, 0.5, 1, 0.5, doneAction: 2);

            // Wrap around the body of func and raise the arguments to the outer level
            snd = SynthDef.wrap(func, lags, [in]);

            // Crossfade with sound already on out bus
            XOut.ar(out, xfade * env, snd);
        }).add;
    };

    ~common_loaded = true;
};
