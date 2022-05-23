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
    var parseData;
    var btnIdxs = (left: 0, right: 1, mute: 2);
    var syncVal = 255; // Special value to mark start of send
    var synced = false;

    "common.scd".loadRelative(true);

    // Serial Init
    ~initData = {
        var portName = "/dev/ttyS0";
        port = SerialPort(portName, 19200, crtscts: true);
        port;
    };

    parseData = {|raw, nfxs, nctrls|
        // Convert to bits
        var bits = raw.collect {|x| 8.collect {|bit| x.bitTest(bit); }; }.flatten;
        // Pad missing bits with 0
        var nbits = (2 * nctrls) + nctrls + nfxs + 3;
        var fullBits = bits ++ (false ! (nbits - bits.size));
        var ctrlOffs = fullBits.keep(2 * nctrls).clump(2).collect {|xs| xs.switch(
            [false, false], { 0 }, // No change
            [false, true], { -1 }, // Left
            [true, false], { 1 },  // Right
            { "Invalid ctrlOff %".format(xs).error; }
        )};
        var btnBits = fullBits.drop(2 * nctrls);
        var ctrlBtns = btnBits.keep(nctrls).indicesOfEqual(true) ? [];
        var btns = btnBits.drop(nctrls).keep(nfxs).indicesOfEqual(true) ? [];
        var leftRightMute = btnBits.drop(nctrls + nfxs).indicesOfEqual(true) ? [];

        (
            mute: leftRightMute.includes(btnIdxs.mute),
            left: leftRightMute.includes(btnIdxs.left),
            right: leftRightMute.includes(btnIdxs.right),
            idxs: btns,
            ctrlOffs: ctrlOffs,
            ctrlBtns: ctrlBtns
        );
    };

    // Read messages from Arduino
    ~readData = {|nfxs, nctrls|
        var byte;
        var data = List[];

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
