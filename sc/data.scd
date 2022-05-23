/*
** Petal
** data.scd
** Wolf Honore
**
** Read sensor data.
*/

// Only execute once
~data_loaded ?? {
    var portName, port;
    var parseData;
    var leftBtn = 0;
    var rightBtn = 1;
    var muteBtn = 2;
    var syncVal = 255; // Special value to mark start of send
    var synced = false;

    "common.scd".loadRelative(true);

    // Serial Init
    ~initData = {
        portName = "/dev/ttyS0";
        port = SerialPort(portName, 19200, crtscts: true);
        port;
    };

    parseData = {|raw, nfxs, nctrls|
        // Convert to bits
        var bits = raw.collect {|x| 8.collect {|bit| x.bitTest(bit); }; }.flatten;
        var ctrlOffs = bits.keep(2 * nctrls).clump(2).collect {|xs| xs.switch(
            [false, false], { 0 }, // No change
            [false, true], { -1 }, // Left
            [true, false], { 1 },  // Right
            { "Invalid ctrlOff %".format(xs).error; }
        )};
        var btnBits = bits.drop(2 * nctrls);
        var encode_btns = btnBits.keep(nctrls).indicesOfEqual(true) ? []; // Unused
        var btns = btnBits.drop(nctrls).keep(nfxs).indicesOfEqual(true) ? [];
        var leftRightMute = btnBits.drop(nctrls + nfxs).indicesOfEqual(true) ? [];

        (
            mute: leftRightMute.includes(muteBtn),
            left: leftRightMute.includes(leftBtn),
            right: leftRightMute.includes(rightBtn),
            idxs: btns,
            ctrlOffs: ctrlOffs,
        );
    };

    // Read messages from Arduino
    ~readData = {|nfxs, nctrls|
        var byte, data;
        data = List[];

        // Wait until syncVal written
        while ({ synced.not.and { port.read != syncVal }}, {});
        synced = true;
        while ({ byte = port.read; byte != syncVal }, {
            data.add(byte);
        });
        parseData.value(data, nfxs, nctrls);
    };

    ~data_loaded = true;
};
