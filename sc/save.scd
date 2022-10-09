/*
** Petal
** save.scd
** Wolf Honore
**
** Save effect settings.
*/

// Only execute once
~save_loaded ?? {
    var initXDG;
    var parseData, saveData;
    var loadData;
    var tmpDir, stateDir, autoSave;

    "common.scd".loadRelative(true);

    initXDG = {|xdg, default|
        var dir = xdg.getenv ? "";
        if (PathName.new(dir).isFolder.not, { dir = default; });
        dir = dir +/+ "petal";
        dir.mkdir;
    };

    // Initialize directories
    tmpDir = initXDG.value("XDG_RUNTIME_DIR", PathName.tmp);
    stateDir = initXDG.value("XDG_STATE_DIR", "~/.local/state".standardizePath);
    ("Runtime directory: " ++ tmpDir).postln;
    ("State directory: " ++ stateDir).postln;

    autoSave = stateDir +/+ ".auto.ptl";

    parseData = {|msg|
        // msg = [_, _, grpID, nfx, fxID, _, fxName, nctrls, ctrlName, ctrlVal, ...]
        var totCtrls = 0;
        var nfx = msg[3];
        var fxs = Array.fill(nfx, {|i|
            var off = 4 + (4 * i) + (2 * totCtrls);
            var fxName = msg[off + 2];
            var nctrls = msg[off + 3];
            var ctrls = msg.drop(off + 4).keep(2 * nctrls).clump(2).collect {|ctrl|
                ctrl[0].isNumber.if({ [ctrl[1]]; }, { ctrl; });
            }.flatten.separate {|x, y| y.isNumber.not; };
            totCtrls = totCtrls + nctrls;
            [fxName] ++ ctrls;
        });
        fxs.drop(1); // Skip dry signal
    };

    saveData = {|msg, name|
        var fxs = parseData.value(msg);
        var file = name !? { stateDir +/+ name ++ ".ptl"; } ? autoSave;
        File.use(file, "w", {|f|
            fxs.do {|fx|
                var repr = fx.collect {|field, idx|
                    (0 < idx).if({ ">" ++ field.join(","); }, { field; });
                }.join("|");
                f.write(repr + "\n");
            };
        });
    };

    loadData = {|file|
        var parse = {|data|
            data.beginsWith(">").if({
                data.drop(1).split($,).collect {|subData| parse.value(subData); };
            }, {
               "\\d+[.]\\d+".matchRegexp(data).if({
                    data.asFloat;
                }, {
                    data.asSymbol;
                });
            });
        };
        PathName.new(file).isFile.if({
            FileReader.read(file, delimiter: $|).collect {|row|
                row.collect {|field| parse.value(field); }
            };
        }, {
            nil;
        });
    };

    // Save effect settings
    ~saveFx = {|serv, grp, name=nil|
        // NOTE: grp.queryTree should work, but for some reason it ignores the
        // callback and just works like dumpTree.
        // Register queryTree callback
        OSCFunc.new({|msg| saveData.value(msg, name); }, '/g_queryTree.reply').oneShot;
        serv.sendMsg("/g_queryTree", grp.nodeID, 1);
    };

    // Load effect settings
    ~loadFx = {|nfxs, active|
        var fxs = loadData.value(autoSave);
        if (fxs.notNil, {
            active.keep(nfxs).do {|oldFx, idx|
                var fxName = fxs[idx][0];
                var ctrls = fxs[idx].drop(1).collect {|ctrl|
                    (ctrl.size > 2).if({ [ctrl[0], ctrl.drop(1)]; }, { ctrl; });
                }.flatten;
                active[idx] = Synth.replace(oldFx, fxName, ctrls);
            };
        });
    };

    ~save_loaded = true;
};
