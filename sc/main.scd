/*
** OneBox
** main.scd
** Wolf Honore
**
** Main event loop.
*/

(
Server.default.quit;
Server.default.waitForBoot({
    var portName, port, syncVal, delay;
    var minFreq, maxFreq;
    var nfxs, nctrls, grp, fxs, ctrls;
    var active, avail, locked, curIdx;
    var readData, cycleActive, main;

    // Imports
    "common.scd".loadRelative(true);
    #ctrls, fxs = "fxs/loadFxs.scd".loadRelative(true)[0];
    ~serv.sync;

    // Serial Init
    portName = "/dev/ttyACM0";
    syncVal = 13; // Special value to mark start of send
    delay = 1; // msec to wait between sending data
    port = SerialPort(
        portName, 9600, crtscts: true
    ).doneAction_({
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
        }.fork;
    });
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

    // Read messages from Arduino
    readData = {
        var mute, leftRight, idxs, ctrl;

        // Wait until syncVal written
        while ({port.read != syncVal}, {});

        mute = port.read;
        leftRight = { port.read } ! 2;
        idxs = { port.read } ! nfxs;

        ctrl = Array.fill(nctrls, {
            var lo = port.read;
            var hi = port.read;
            (hi << 8) | lo;
        }).linlin(0, 1023, 0, 1);

        [mute, leftRight, idxs, ctrl];
    };

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

    // Main event loop
    main = Routine {
        var oldMute = 0;
        var oldLeftRight = 0 ! 2;
        var oldIdxs = 0 ! nfxs;
        var oldData = 0 ! nctrls;
        var muted = nil;

        loop {
            var fx, fxName;
            var mute, leftRight, idxs;
            var ctrl, data, vals;

            fx = active[curIdx];
            fxName = fx.defName;
            ctrl = ctrls[fxName];

            ("Active: " + fxName).postln;
            ("Mute: " + muted.notNil).postln;

            #mute, leftRight, idxs, data = readData.value();

            // Toggle mute
            if (mute - oldMute > 0, {
                if (muted.isNil, {
                    muted = Synth.tail(grp, \mute, [\inbus, [0, 0]]);
                }, {
                    muted.free;
                    muted = nil;
                });
            });

            // Change fx
            (leftRight - oldLeftRight).do {|dif, idx|
                if (dif > 0, {
                    fx = cycleActive.value(fxName, idx.linlin(0, 1, -1, 1));
                });
            };

            // Update current index
            (idxs - oldIdxs).do {|dif, idx|
                if (dif > 0, {
                    // Lock old current index
                    locked[curIdx] = true;
                    curIdx = idx + 1;
                });
            };

            // Unlock current index if any value changed
            if ((data - oldData).abs.any(_ > 1), {
                locked[curIdx] = false;
            });

            // Map raw values to correct range for current fx
            vals = ctrl.collect {|ctrlSpec, idx|
                [ctrlSpec.key, ctrlSpec.value.map(data[idx])];
            }.flat;

            // Update if not locked
            if (locked[curIdx].not, {
                fx.set(*vals);
            });

            oldMute = mute;
            oldLeftRight = leftRight;
            oldIdxs = idxs;
            oldData = data;

            (delay / 1000).wait;
        };
    };

    // Launch main loop
    main.play;
});
);
