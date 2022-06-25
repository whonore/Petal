/*
** Petal
** main.scd
** Wolf Honore
**
** Main event loop.
*/

(
~debug = false;

Server.default.quit;
Server.default.waitForBoot({
    var minFreq, maxFreq;
    var port;
    var version;
    var nfxs, nctrls, bigStep, grp, fxs, fxInfo;
    var active;
    var titleFont, display, labels;
    var soundSrc, cycleActive, swapActive, updateDisplay, debugLog, main;

    // Imports
    "common.scd".loadRelative(true);
    "data.scd".loadRelative(true);
    #fxInfo, fxs = "fxs/loadFxs.scd".loadRelative(true)[0];
    version = File.open("../VERSION".resolveRelative, "r").readAllString.replace("\n", "");

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
    maxFreq = 3000;
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
    bigStep = 5;
    grp = Group(~serv);
    ~serv.sync;

    // Display Init
    Font.default = Font.new(Font.defaultSansFace, 32);
    titleFont = Font.default.bold_(true);
    display = Window.new(
        "Petal", Window.availableBounds, resizable: false, border: false, scroll: false
    );
    labels = (
        title: StaticText.new().string_("Petal (v%)".format(version)).font_(titleFont),
        muted: StaticText.new(),
        active: StaticText.new(),
        ctrls: {(
            lbl: StaticText.new().minWidth_(display.bounds.width),
            knob: Knob.new().bounds_(100 @ 100)
        )} ! nctrls,
    );
    display.layout = VLayout.new(
        [labels.title, align: \center],
        labels.muted,
        [labels.active, stretch: 1],
        5,
        *labels.ctrls.collect({|ctrl|
            HLayout.new(
                ctrl.knob,
                [ctrl.lbl, align: \left, stretch: 1]
            )
        })
    );
    display.front;

    // Add xfade as a control to all fxs except dummy
    fxInfo.keysValuesDo {|fx, info|
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

    // Swap two fxs
    swapActive = {|fromIdx, toIdx|
        var fromFxName = active[fromIdx].defName;
        var toFxName = active[toIdx].defName;
        var oldFromFx = active[fromIdx].copy;
        var fromCtrls = IdentityDictionary.new();
        var toCtrls = IdentityDictionary.new();
        fxInfo[fromFxName].ctrls.do {|ctrl|
            active[fromIdx].get(ctrl.key, {|val|
                fromCtrls[ctrl.key] = val;
            });
        };
        fxInfo[toFxName].ctrls.do {|ctrl|
            active[toIdx].get(ctrl.key, {|val|
                toCtrls[ctrl.key] = val;
            });
        };

        // Wait to read the controls
        block {|break|
            var retries = 3;
            retries.do{|i|
                if (fromCtrls.keys.size == fxInfo[fromFxName].ctrls.size &&
                    (toCtrls.keys.size == fxInfo[toFxName].ctrls.size), {
                    break.value();
                });
                ~serv.sync;
            };
            "Failed to read controls after % attemps".format(retries).warn;
        };

        active[fromIdx] = Synth.replace(
            active[toIdx],
            toFxName,
            fxInfo[toFxName].ctrls.collect {|ctrl|
                [ctrl.key, toCtrls[ctrl.key]]
            }.flat,
        );
        active[toIdx] = Synth.replace(
            oldFromFx,
            fromFxName,
            fxInfo[fromFxName].ctrls.collect {|ctrl|
                [ctrl.key, fromCtrls[ctrl.key]]
            }.flat,
        );
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
            if (data.curIdx.isNil.not && (data.curIdx != curIdx), {
                // Lock old current index
                locked[curIdx] = true;
                curIdx = data.curIdx;
                changed = true;
            });

            // Swap indices
            if (data.swap.isNil.not, {
                swapActive.value(data.swap[0], data.swap[1]);
                changed = true;
            });

            // Update if any control changed
            if (data.ctrlOffs.any {|x| x != 0; }, {
                // Map raw values to correct range for current fx
                ctrls.do {|ctrl, idx|
                    var spec = ctrl.value.spec;
                    var step = spec.step * data.ctrlBtns.includes(idx).if({ bigStep }, { 1 });
                    var off = data.ctrlOffs[idx] * step;
                    fx.get(ctrl.key, {|cur|
                        fx.set(ctrl.key, spec.constrain(cur + off));
                    })
                };
                ~serv.sync;
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

// Debugging cleanup
(
if (~debug, {
    SerialPort.closeAll;
    Window.closeAll;
});
)
