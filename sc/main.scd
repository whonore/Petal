/*
** OneBox
** main.scd
** Wolf Honore
**
** Main event loop.
*/

(
~debug = true;

Server.default.quit;
Server.default.waitForBoot({
    var minFreq, maxFreq;
    var port;
    var nfxs, nctrls, grp, fxs, ctrls;
    var active, avail, locked, curIdx;
    var cycleActive, debugLog, main;

    // Imports
    "common.scd".loadRelative(true);
    "data.scd".loadRelative(true);
    #ctrls, fxs = "fxs/loadFxs.scd".loadRelative(true)[0];

    // Initialize serial port
    port = ~initData.value();
    port.doneAction = {
        "Cleaning up".postln;
        {
            main.stop;
            active.do {|s| s.release; };
            grp.free;
            ~pitchBus.free;
            ~ampBus.free;
            Buffer.freeAll(~serv);
            port.close;
            ~serv.sync;
            ~serv.quit;
            ~common_loaded = nil;
            ~data_loaded = nil;
        }.fork
    };
    ~serv.sync;

    // SynthDef Init
    minFreq = 20;
    maxFreq = 1000;
    // Get the dry signal and track pitch and amplitude
    SynthDef(\dry, {|inbus=#[0, 1], outbus=0, volume=1|
        var in, freq, amp;

        // Scale amplitude
        in = volume * SoundIn.ar(inbus);

        // Track pitch and amplitude
        freq = Pitch.kr(in, minFreq: minFreq, maxFreq: maxFreq).flop[0];
        amp = Amplitude.ar(in);

        Out.kr(~pitchBus, freq);
        Out.ar(~ampBus, amp);

        Out.ar(outbus, in);
    }).add;

    // Mute all fxs and play only the dry signal
    SynthDef(\mute, {|inbus=#[0, 1], outbus=0, volume=1|
        ReplaceOut.ar(outbus, volume * SoundIn.ar(inbus));
    }).add;

    // Pass the signal untouched
    ~makeFx.value(\dummy, {|in| in; });
    fxs.insert(0, \dummy);
    ctrls[\dummy] = [];

    // Synth Init
    nfxs = 4; // Number of active fxs
    nctrls = 5; // Max number of controls
    curIdx = 1;
    grp = Group(~serv);
    ~serv.sync;

    // Add xfade as a control to all fxs except dummy
    ctrls.do {|ctrl, fx|
        if (fx != \dummy, {
            ctrl = ctrl.addFirst(\xfade -> ControlSpec(0, 1, step: 0.01, default: 1));
        });
    };

    // Initalize all fxs as dummies and dry at the head
    active = { Synth.tail(grp, \dummy); } ! nfxs;
    active = active.insert(0, Synth.head(grp, \dry, [\inbus, [0, 0]]));

    avail = true ! fxs.size;
    locked = false ! active.size;

    // Change the active fx to the next unused one
    cycleActive = {|fxName, step|
        var availIdx, nextAvailIdx, nextAvail;

        // Find idx of fx with fxName
        availIdx = fxs.indexOf(fxName);

        // Search for next fx that is not already used
        nextAvailIdx = availIdx + step;
        while ({ avail.wrapAt(nextAvailIdx).not }, {
            nextAvailIdx = nextAvailIdx + step;
        });
        nextAvail = fxs.wrapAt(nextAvailIdx);

        // Replace synth
        active[curIdx] = Synth.replace(
            active[curIdx],
            nextAvail,
            ctrls[nextAvail].collect {|ctrlSpec|
                [ctrlSpec.key, ctrlSpec.value.default]
            }.flat
        );

        // Mark new fx as unavailable and old as available
        if (nextAvail != \dummy, {
            avail.wrapPut(nextAvailIdx, false);
        });
        avail[availIdx] = true;

        active[curIdx];
    };

    debugLog = {|curIdx, muted, active, ctrls, locked|
        if (~debug, {
            postf("CurIdx: %\nActive: %\nMuted: %\n", curIdx, active[curIdx].defName, muted.notNil);
            active[1..].do {|fx, idx|
                postf("% %controls: [ ", fx.defName, if (locked[idx + 1], { "(locked) " }, { "" }));
                ctrls[fx.defName].do {|ctrl|
                    fx.get(ctrl.key, {|val|
                        postf("%=% ", ctrl.key, val);
                    });
                };
                ~serv.sync;
                "]".postln;
            };
        });
    };

    // Main event loop
    main = Routine {
        var muted = nil;

        loop {
            var fx, fxName;
            var mute, left, right, idxs;
            var ctrl, data, newData, vals;

            fx = active[curIdx];
            fxName = fx.defName;
            ctrl = ctrls[fxName];

            #mute, left, right, idxs, data, newData = ~readData.value(nfxs, nctrls);

            // Toggle mute
            if (mute, {
                if (muted.isNil, {
                    muted = Synth.tail(grp, \mute, [\inbus, [0, 0]]);
                }, {
                    muted.free;
                    muted = nil;
                });
            });

            // Change fx
            if (left || right) {
                fx = cycleActive.value(fxName, if (left, { -1 }, { 1 }));
            };

            // Update current index
            idxs.do {|pressed, idx|
                if (pressed, {
                    // Lock old current index
                    locked[curIdx] = true;
                    curIdx = idx + 1;
                });
            };

            // Unlock current index if any value changed
            if (newData, { locked[curIdx] = false; });

            // Map raw values to correct range for current fx
            vals = ctrl.collect {|ctrlSpec, idx|
                [ctrlSpec.key, ctrlSpec.value.map(data[idx])];
            }.flat;

            // Update if not locked
            if (locked[curIdx].not, { fx.set(*vals); });

            // Log new values
            debugLog.value(curIdx, muted, active, ctrls, locked);

            (~dataDelay / 1000).wait;
        };
    };

    // Launch main loop
    main.play;
});
);

// For debugging
SerialPort.closeAll;
