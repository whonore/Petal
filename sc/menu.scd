/*
** Petal
** menu.scd
** Wolf Honore
**
** Save/load menu.
*/

// Only execute once
~menu_loaded ?? {
    var profiles, profileIdx;
    var menu, profileList, labels;
    var promptName, curProfile, selectProfile, actProfile, updateMenu;

    "common.scd".loadRelative(true);

    menu = Window.new(
        "Petal", Window.availableBounds, resizable: false, border: false, scroll: false
    );
    labels = (
        title: StaticText.new().string_("Manage Profiles"),
        exit: StaticText.new().string_("Stomp:\nExit"),
        save: StaticText.new(),
        load: StaticText.new(),
        delete: StaticText.new(),
    );
    profileList = ListView.new();
    menu.layout = VLayout.new(
        [labels.title, align: \center],
        HLayout.new(
            labels.save,
            labels.load,
            labels.delete,
            labels.exit,
        ),
        profileList,
    );

    promptName = {|nfxs, nctrls|
        var name = nil;
        var quit = false;
        var cancel = false;
        var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var nameBuf = [chars[0]];
        var cursorIdx = 0;
        var charIdx = 0;
        var deleteHack = false;
        var deleteHackDelay = 0.3; // 300ms
        var popup, label;

        var updateLabel = {
            {
                label.string = nameBuf.join("");
                label.select(cursorIdx, 1);
            }.defer;
        };

        {
            var bounds = (800 @ 250).asRect.center_(Window.availableBounds.center);
            popup = Window.new(
                "Update Message", bounds, resizable: false, border: false, scroll: false
            );
            label = TextView.new();
            popup.layout = VLayout.new(
                HLayout.new(
                    StaticText.new().string_("Turn any knob:\nSelect letter"),
                    StaticText.new().string_("Click any knob:\nDelete letter"),
                    StaticText.new().string_("Left/right button:\nMove cursor"),
                    StaticText.new().string_("Any button:\nConfirm"),
                    StaticText.new().string_("Stomp:\nCancel"),
                ),
                label,
            );
            popup.front;
        }.defer;

        updateLabel.value();
        while ({ quit.not; }, {
            var data = ~readData.value(nfxs, nctrls);

            // Move cursor
            if ((data.left || data.right), {
                var off = data.left.if({ -1 }, { 1 });
                cursorIdx = (cursorIdx + off).clip(0, nameBuf.size);
                if (cursorIdx == nameBuf.size, {
                    nameBuf = nameBuf.add(chars[0]);
                });
                charIdx = chars.detectIndex {|c| c == nameBuf[cursorIdx]; };
                updateLabel.value();
            });

            // Change character selection
            if (data.ctrlOffs.any {|x| x != 0; }, {
                var ctrl = data.ctrlOffs.detect {|x| x != 0; };
                var off = (ctrl > 0).if({ 1; }, { -1; });
                charIdx = (charIdx + off) % chars.size;
                nameBuf[cursorIdx] = chars[charIdx];
                updateLabel.value();
            });

            // Delete character
            if (data.ctrlBtns.isEmpty.not && (1 < nameBuf.size) && deleteHack.not, {
                nameBuf.removeAt(cursorIdx);
                cursorIdx = (cursorIdx - 1).clip(0, nameBuf.size);
                charIdx = chars.detectIndex {|c| c == nameBuf[cursorIdx]; };
                updateLabel.value();
                { deleteHack = false; }.defer(deleteHackDelay);
            });
            // NOTE: hack to require knob to released between deletions
            deleteHack = data.ctrlBtns.isEmpty.not;

            // Confirm
            if (data.curIdx.notNil, {
                quit = true;
            });

            // Cancel
            cancel = data.mute;

            quit = quit || cancel;
        });

        { popup.close; }.defer;

        (cancel || (nameBuf.size == 0)).if({ nil; }, { nameBuf.join(""); });
    };

    curProfile = {
        case
            { profileIdx == 0; } { (name: nil, path: nil, type: \new); }
            { (profileIdx - 1) < profiles.saved.size } {
                var prof = profiles.saved[profileIdx - 1];
                (name: prof.name, path: prof.path, type: \saved);
            }
            {
                var prof = profiles.deleted[profileIdx - profiles.saved.size - 1];
                (name: prof.name, path: prof.path, type: \deleted);
            };
    };

    selectProfile = {|off|
        {
            var max = profileList.items.size;
            profileList.value = (profileIdx + off) % max;
            profileIdx = profileList.value;
        }.defer;
    };

    actProfile = {|btn, serv, grp, active, nfxs, nctrls|
        var save = {|name|
            ~saveProfile.value(~serv, grp, name, sync: true);
        };
        var load = {|path|
            ~loadProfile.value(nfxs, active, path);
        };
        var delete = {|path, keep=true|
            ~deleteProfile.value(path, keep: keep);
        };
        var restore = {|path|
            ~restoreProfile.value(path);
        };

        var profile = curProfile.value();

        profile.type.switch(
            \new, {
                btn.switch(
                    0, {
                        var name = promptName.value(nfxs, nctrls);
                        if (name.notNil, {
                            save.value(name);
                        });
                    },
                    { },
                );
            },
            \saved, {
                btn.switch(
                    0, {
                        delete.value(profile.path, keep: false);
                        save.value(profile.name);
                    },
                    1, { load.value(profile.path); },
                    2, { delete.value(profile.path); },
                    { },
                );
            },
            \deleted, {
                btn.switch(
                    0, { restore.value(profile.path); },
                    { },
                );
            }
        );
    };

    updateMenu = {|reload|
        {
            var profile;

            if (reload, {
                var saved, deleted, idx;
                profiles = ~listProfiles.value();
                saved = profiles.saved.collect {|profile|
                    "% -- %".format(profile.name, profile.time);
                };
                deleted = profiles.deleted.collect {|profile|
                    "% (deleted) -- %".format(profile.name, profile.time);
                };
                profileList.items = ["(New)"] ++ saved ++ deleted;
                profileList.value = profileIdx.clip(0, profileList.items.size - 1);
                profileIdx = profileList.value;
            });

            profile = curProfile.value();
            profile.type.switch(
                \new, {
                    labels.save.string = "Button 1:\nSave";
                    labels.load.string = "Button 2:\nN/A";
                    labels.delete.string = "Button 3:\nN/A";
                },
                \saved, {
                    labels.save.string = "Button 1:\nOverwrite";
                    labels.load.string = "Button 2:\nLoad";
                    labels.delete.string = "Button 3:\nDelete";
                },
                \deleted, {
                    labels.save.string = "Button 1:\nRecover";
                    labels.load.string = "Button 2:\nN/A";
                    labels.delete.string = "Button 3:\nN/A";
                },
            )
        }.defer;
    };

    // Manage profiles
    ~menuMain = {|serv, grp, active, nfxs, nctrls|
        var quit = false;
        profileIdx = 0;

        // Display menu
        { menu.front; }.defer;
        updateMenu.value(true);

        // Wait for commands
        while ({ quit.not; }, {
            var data = ~readData.value(nfxs, nctrls);
            var reload = false;
            var changed = false;

            // Act on current selection
            if (data.curIdx.notNil, {
                actProfile.value(data.curIdx, serv, grp, active, nfxs, nctrls);
                reload = true;
                changed = true;
            });

            // Change selection
            if (data.ctrlOffs.any {|x| x != 0; }, {
                var ctrl = data.ctrlOffs.detect {|x| x != 0; };
                var off = (ctrl > 0).if({ 1; }, { -1; });
                selectProfile.value(off);
                changed = true;
            });

            // Quit
            quit = data.mute;

            if (changed, {
                updateMenu.value(reload);
            });
        });

        // Cleanup
        { menu.visible = false; }.defer
    };

    ~menu_loaded = true;
};
