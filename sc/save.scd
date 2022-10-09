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
    var profilePath, buildProfile, serializeProfile, deserializeProfile;
    var tmpDir, stateDir, profileDir, autoSave;

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
    profileDir = stateDir +/+ "profiles";
    profileDir.mkdir;
    ("Runtime directory: " ++ tmpDir).postln;
    ("State directory: " ++ stateDir).postln;

    autoSave = profileDir +/+ ".auto.ptl";

    profilePath = {|name|
        name !? { profileDir +/+ name ++ ".ptl"; } ? autoSave;
    };

    buildProfile = {|msg|
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
        }).drop(1); // Skip dry signal
        fxs;
    };

    serializeProfile = {|fxs|
        fxs.collect {|fx|
            fx.collect {|field, idx|
                (0 < idx).if({ ">" ++ field.join(","); }, { field; });
            }.join("|");
        }.join("\n");
    };

    deserializeProfile = {|file|
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
    ~saveProfile = {|serv, grp, name=nil|
        var save = {|msg|
            var fxs = buildProfile.value(msg);
            var file = profilePath.value(name);
            File.use(file, "w", {|f| f.write(serializeProfile.value(fxs)); });
        };

        // NOTE: grp.queryTree should work, but for some reason it ignores the
        // callback and just works like dumpTree.
        // Register queryTree callback
        OSCFunc.new({|msg| save.value(msg); }, '/g_queryTree.reply').oneShot;
        serv.sendMsg("/g_queryTree", grp.nodeID, 1);
    };

    // Load effect settings
    ~loadProfile = {|nfxs, active, name=nil|
        var file = profilePath.value(name);
        var fxs = deserializeProfile.value(file);
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