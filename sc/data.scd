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
    var parseInt, parseData, setLEDs, showPopup, doUpdate, checkUpdate, showIP;
    var ledScript = "../scripts/set_led.py".resolveRelative;
    var ipScript = "../scripts/get_ip".resolveRelative;
    var chkUpdScript = "../scripts/check_update".resolveRelative;
    var doUpdScript = "../scripts/do_update".resolveRelative;
    var updHeld = 3; // Rightmost idx button
    var updBtn = 4;  // Rightmost ctrl button
    var ipBtn = 3;
    var checking = false; // Currently checking for updates
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

        var ip = (held.includes(updHeld) && (ctrlBtns.includes(ipBtn)));

        (
            mute: leftRightMute.includes(btnIdxs.mute),
            left: leftRightMute.includes(btnIdxs.left),
            right: leftRightMute.includes(btnIdxs.right),
            curIdx: swap.not.if({ btns.maxItem; }, { nil; }),
            swap: swap.if({ held; }, { nil; }),
            ctrlOffs: ctrlOffs,
            ctrlBtns: ctrlBtns,
            doUpdate: update,
            ip: ip,
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

    showPopup = {|msg, delay|
        {
            var bounds = (400 @ 100).asRect.center_(Window.availableBounds.center);
            var popup = Window.new(
                "Update Message", bounds, resizable: false, border: false, scroll: false
            );
            popup.layout = HLayout.new(StaticText.new(popup).string_(msg).align_(\center));
            popup.front;
            {
                popup.close();
                checking = false;
            }.defer(delay);
        }.defer;
    };

    checkUpdate = {
        checking = true;
        chkUpdScript.unixCmd(
            {|exit| if (exit == 0, {
                doUpdate.value();
            }, {
                showPopup.value("No available updates", 2);
            }); },
            postOutput: false
        );
    };

    showIP = {
        var ip = ipScript.unixCmdGetStdOut();
        checking = true;
        showPopup.value(ip.isEmpty.if({ "No IP"; }, { "IP: %".format(ip); }), 2);
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
        if (parsed.doUpdate && checking.not, { checkUpdate.value(); });
        if (parsed.ip && checking.not, { showIP.value(); });

        parsed;
    };

    ~data_loaded = true;
};
