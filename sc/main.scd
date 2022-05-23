/*
** Petal
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
    var nfxs, nctrls, grp, fxs, fxInfo;
    var active, avail, locked;
    var display, labels;
    var soundSrc, cycleActive, updateDisplay, debugLog, main;

    // Imports
    "common.scd".loadRelative(true);
    "data.scd".loadRelative(true);
    #fxInfo, fxs = "fxs/loadFxs.scd".loadRelative(true)[0];

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
            Window.closeAll;
            port.close;
            ~serv.sync;
            ~serv.quit;
            ~common_loaded = nil;
            ~data_loaded = nil;
        }.fork
    };
    ~serv.sync;

    soundSrc = {|bus|
        ~debug.if({
            SinOsc.ar(220 + 220 * LFTri.kr(TRand.kr(0.1, 0.5, Dust.kr(1))).unipolar)
        }, {
            SoundIn.ar(bus)
        });
    };

    // SynthDef Init
    minFreq = 20;
    maxFreq = 1000;
    // Get the dry signal and track pitch and amplitude
    SynthDef(\dry, {|inbus=#[0, 1], outbus=0, volume=1|
        var in, freq, amp;

        // Scale amplitude
        in = volume * soundSrc.value(inbus);

        // Track pitch and amplitude
        freq = Pitch.kr(in, minFreq: minFreq, maxFreq: maxFreq).flop[0];
        amp = Amplitude.ar(in);

        Out.kr(~pitchBus, freq);
        Out.ar(~ampBus, amp);

        Out.ar(outbus, in);
    }).add;

    // Mute all fxs and play only the dry signal
    SynthDef(\mute, {|inbus=#[0, 1], outbus=0, volume=1|
        ReplaceOut.ar(outbus, volume * soundSrc.value(inbus));
    }).add;

    // Pass the signal untouched
    ~makeFx.value(\dummy, {|in| in; });
    fxs.insert(0, \dummy);
    fxInfo[\dummy] = (
        name: "Passthrough",
        desc: "Passes the signal untouched.",
        ctrls: []
    );

    // Synth Init
    nfxs = 4; // Number of active fxs
    nctrls = 5; // Max number of controls
    grp = Group(~serv);
    ~serv.sync;

    // Display Init
    display = Window.new(
        "Petal", resizable: false, border: false, scroll: false
    ).alwaysOnTop_(true);
    labels = (
        muted: StaticText.new(),
        active: StaticText.new(),
        ctrls: { (lbl: StaticText.new(), knob: Knob.new()) } ! nctrls,
    );
    display.layout = VLayout.new(
        labels.muted,
        labels.active,
        [
            VLayout.new(*labels.ctrls.collect({|ctrl|
                HLayout.new(
                    [ctrl.knob, align: \left],
                    [ctrl.lbl, align: \left],
                    [nil, stretch: 1]
                )
            })),
            align: \center
        ],
        [nil, strech: 1]
    );
    display.front;

    // Add xfade as a control to all fxs except dummy
    fxInfo.do {|info, fx|
        if (fx != \dummy, {
            info.ctrls = info.ctrls.addFirst(
                \xfade -> (
                    name: "Volume",
                    spec: ControlSpec(0, 1, step: 0.01, default: 1, units: \pct)
                )
            );
        });
    };

    // Initalize all fxs as dummies and dry at the head
    active = { Synth.tail(grp, \dummy); } ! nfxs;
    active = active.add(Synth.head(grp, \dry, [\inbus, [0, 0]]));

    // Change the active fx to the next unused one
    cycleActive = {|fxName, curIdx, avail, step|
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
            fxInfo[nextAvail].ctrls.collect {|ctrl|
                [ctrl.key, ctrl.value.spec.default]
            }.flat
        );

        // Mark new fx as unavailable and old as available
        if (nextAvail != \dummy, {
            avail.wrapPut(nextAvailIdx, false);
        });
        avail[availIdx] = true;

        active[curIdx];
    };

    updateDisplay = {|curIdx, muted, active, fxInfo, locked|
        var fx = active[curIdx];
        {
            labels.muted.string = "Bypass All: %".format(
                muted.notNil.if({ "On" }, { "Off" })
            );
            labels.active.string = "Focused Effect: % (slot %)\n%".format(
                fxInfo[fx.defName].name,
                curIdx + 1,
                fxInfo[fx.defName].desc,
            );
            labels.ctrls.do {|label, idx|
                var ctrl = fxInfo[fx.defName].ctrls[idx];
                ctrl.notNil.if({
                    fx.get(ctrl.key, {|val|
                        var spec = ctrl.value.spec;
                        {
                            label.lbl.string = "%: %".format(
                                ctrl.value.name,
                                spec.units.switch(
                                    \pct, { "%\\%".format((val * 100).round(1).asInteger); },
                                    \hz, { "% Hz".format(val.round(0.01)); },
                                    \sec, { "% sec".format(val.round(0.01)); },
                                    \mult, { "%x".format(val.round(0.01)); },
                                    { val.round(0.01); }
                                )
                            );
                            label.knob.value = spec.unmap(val);
                        }.defer;
                    });
                }, {
                    label.lbl.string = "N/A";
                    label.knob.value = 0;
                })
            };
        }.defer;
    };

    debugLog = {|curIdx, muted, active, fxInfo, locked|
        if (~debug, {
            postf("CurIdx: %\nActive: %\nMuted: %\n", curIdx, active[curIdx].defName, muted.notNil);
            active.drop(-1).do {|fx, idx|
                postf("% %controls: [ ", fx.defName, locked[idx].if({ "(locked) " }, { "" }));
                fxInfo[fx.defName].ctrls.do {|ctrl|
                    fx.get(ctrl.key, {|val|
                        postf("%=% ", ctrl.key, val.round(0.01));
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
        var curIdx = 0;
        var avail = true ! fxs.size;
        var locked = false ! nfxs;

        updateDisplay.value(curIdx, muted, active, fxInfo, locked);
        loop {
            var fx, fxName;
            var ctrls, data;
            var changed = false;

            fx = active[curIdx];
            fxName = fx.defName;
            ctrls = fxInfo[fxName].ctrls;
            data = ~readData.value(nfxs, nctrls);

            // Toggle mute
            if (data.mute, {
                muted = muted.isNil.if({
                    Synth.tail(grp, \mute, [\inbus, [0, 0]]);
                }, {
                    muted.free;
                    nil;
                });
                changed = true;
            });

            // Change fx
            if (data.left || data.right) {
                fx = cycleActive.value(
                    fxName, curIdx, avail, data.left.if({ -1 }, { 1 })
                );
                changed = true;
            };

            // Update current index
            data.idxs.do {|idx|
                if (idx != curIdx, {
                    // Lock old current index
                    locked[curIdx] = true;
                    curIdx = idx;
                    changed = true;
                });
            };

            // Update if any control changed
            if (data.ctrlOffs.any {|x| x != 0; }, {
                // Map raw values to correct range for current fx
                ctrls.do {|ctrl, idx|
                    var spec = ctrl.value.spec;
                    fx.get(ctrl.key, {|cur|
                        var off = data.ctrlOffs[idx] * spec.step;
                        var new = spec.map(spec.unmap(cur) + off);
                        fx.set(ctrl.key, new);
                    })
                };
                changed = true;
            });

            // Log new values
            if (changed, {
                updateDisplay.value(curIdx, muted, active, fxInfo, locked);
                // debugLog.value(curIdx, muted, active, fxInfo, locked);
            });
        };
    };

    // Launch main loop
    main.play;
});
);

// For debugging
SerialPort.closeAll;
Window.closeAll;
