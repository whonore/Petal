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
    var curProfile, selectProfile, actProfile, updateMenu;

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
            labels.exit,
            labels.save,
            labels.load,
            labels.delete,
        ),
        profileList,
    );

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
                        var name = "TEMP";
                        save.value(name);
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
            if (data.ctrlOffs[0] != 0, {
                var off = (data.ctrlOffs[0] > 0).if({ 1; }, { -1; });
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
