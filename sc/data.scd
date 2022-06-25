/*
** Petal
** data.scd
** Wolf Honore
**
** Read sensor data.
*/

// Only execute once
~data_loaded ?? {
    var port;
    var parseInt, parseData, setLEDs, doUpdate, noUpdate, checkUpdate;
    var ledScript = "../scripts/set_led.py".resolveRelative;
    var chkUpdScript = "../scripts/check_update".resolveRelative;
    var doUpdScript = "../scripts/do_update".resolveRelative;
    var updHeld = 3; // Rightmost idx button
    var updBtn = 4;  // Rightmost ctrl button
    var btnIdxs = (left: 0, right: 1, mute: 2);
    var syncVal = 255; // Special value to mark end of send
    var synced = false;
    var maxInt8 = ((1 << 7) - 1).asInteger;

    "common.scd".loadRelative(true);

    // Serial Init
    ~initData = {
        var portName = "/dev/ttyS0";
        port = SerialPort(portName, 115200, crtscts: true);
        port;
    };

    parseInt = {|bitsBool|
        var bits = bitsBool.reverse.collect {|bit| bit.if({ 1; }, { 0; }); };
        var sign = bits[0];
        var v = bits.drop(1).convertDigits(2);
        // Extra +1 to account for negative offset (see readEncoderOff)
        (sign == 1).if({(maxInt8 - v + 1).neg + 1; }, { v; });
    };

    parseData = {|raw, nfxs, nctrls|
        // Convert to bits
        var bits = raw.collect {|x| 8.collect {|bit| x.bitTest(bit); }; }.flatten;
        // Pad missing bits with 0
        var nbits = (8 * nctrls) + nctrls + 2 * (nfxs + 3);
        var fullBits = bits ++ (false ! (nbits - bits.size));
        var ctrlOffs = fullBits.keep(8 * nctrls).clump(8).collect {|xs| parseInt.value(xs); };
        var btnBits = fullBits.drop(8 * nctrls);
        var ctrlBtns = btnBits.keep(nctrls).indicesOfEqual(true) ? [];
        var btns = btnBits.drop(nctrls).keep(nfxs).indicesOfEqual(true) ? [];
        var leftRightMute = btnBits.drop(nctrls + nfxs).keep(3).indicesOfEqual(true) ? [];
        var held = btnBits.drop(nctrls + nfxs + 3).keep(nfxs).indicesOfEqual(true) ? [];

        // Swap if exactly two buttons are held and one was also pressed
        var swap = (held.size == 2 && (held.any {|idx| btns.includes(idx); }));

        // Check for updates if rightmost idx button is held and rightmost ctrl
        // button is pressed
        var update = (held.includes(updHeld) && (ctrlBtns.includes(updBtn)));

        (
            mute: leftRightMute.includes(btnIdxs.mute),
            left: leftRightMute.includes(btnIdxs.left),
            right: leftRightMute.includes(btnIdxs.right),
            curIdx: swap.not.if({ btns.maxItem; }, { nil; }),
            swap: swap.if({ held; }, { nil; }),
            ctrlOffs: ctrlOffs,
            ctrlBtns: ctrlBtns,
            doUpdate: update,
        );
    };

    setLEDs = {|nfxs, curIdx|
        if (curIdx.isNil.not, {
            var vals = "0" ! nfxs;
            vals[curIdx] = "1";
            ([ledScript] ++ vals).unixCmd(postOutput: false);
        });
    };

    doUpdate = {
        doUpdScript.unixCmd(postOutput: false);
    };

    noUpdate = {
        {
            var bounds = (400 @ 80).asRect.center_(Window.availableBounds.center);
            var popup = Window.new(
                "Update Message", bounds, resizable: false, border: false, scroll: false
            );
            var msg = StaticText.new(popup).string_("No available updates").align_(\center);
            popup.layout = HLayout.new(msg);
            popup.front;
            {
                popup.close();
            }.defer(2);
        }.defer;
    };

    checkUpdate = {
        chkUpdScript.unixCmd(
            {|exit| if (exit == 0, { doUpdate.value(); }, { noUpdate.value(); }); },
            postOutput: false
        );
    };

    // Read messages from Arduino
    ~readData = {|nfxs, nctrls|
        var byte, parsed;
        var data = List[];

        // Wait until syncVal written
        if (synced.not, {
            setLEDs.value(nfxs, [0]);
            while ({ port.read != syncVal }, {});
        });
        synced = true;

        while ({ byte = port.read; byte != syncVal }, {
            data.add(byte);
        });
        parsed = parseData.value(data, nfxs, nctrls);

        setLEDs.value(nfxs, parsed.curIdx);
        if (parsed.doUpdate, { checkUpdate.value(); });

        parsed;
    };

    ~data_loaded = true;
};
