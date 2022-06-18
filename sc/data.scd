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
    var btnIdxs = (left: 0, right: 1, mute: 2);
    var syncVal = 255; // Special value to mark end of send
    var synced = false;
    var updCount = 0;
    var updBtn = 3;
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
        var nbits = (8 * nctrls) + nctrls + nfxs + 3;
        var fullBits = bits ++ (false ! (nbits - bits.size));
        var ctrlOffs = fullBits.keep(8 * nctrls).clump(8).collect {|xs| parseInt.value(xs); };
        var btnBits = fullBits.drop(8 * nctrls);
        var ctrlBtns = btnBits.keep(nctrls).indicesOfEqual(true) ? [];
        var btns = btnBits.drop(nctrls).keep(nfxs).indicesOfEqual(true) ? [];
        var leftRightMute = btnBits.drop(nctrls + nfxs).indicesOfEqual(true) ? [];

        (
            mute: leftRightMute.includes(btnIdxs.mute),
            left: leftRightMute.includes(btnIdxs.left),
            right: leftRightMute.includes(btnIdxs.right),
            curIdx: btns.maxItem,
            ctrlOffs: ctrlOffs,
            ctrlBtns: ctrlBtns
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

    checkUpdate = {|parsed|
        (parsed.curIdx == updBtn).if({
            updCount = updCount + 1;
            if (updCount == 3, {
                chkUpdScript.unixCmd(
                    {|exit| if (exit == 0, { doUpdate.value(); }, { noUpdate.value(); }); },
                    postOutput: false
                );
                updCount = 0;
            });
        }, {
            updCount = 0;
        });
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
        checkUpdate.value(parsed);

        parsed;
    };

    ~data_loaded = true;
};
