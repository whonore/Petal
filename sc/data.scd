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
    var oldCtrls;
    var parseData;
    var leftBtn = 0;
    var rightBtn = 1;
    var muteBtn = 2;
    var syncVal = 128; // Special value to mark start of send
    var synced = false;

    "common.scd".loadRelative(true);

    // Serial Init
    ~initData = {
        portName = if (~debug.not, { "/dev/ttyS0" }, { "../ino/tmppty".resolveRelative });
        portName = "/dev/ttyS0"; // TODO: remove
        port = SerialPort(portName, 19200, crtscts: true);
        port;
    };

    parseData = {|raw, nfxs, nctrls|
        var ctrls = raw.keep(nctrls).linlin(0, 127, 0, 1);
        var encoders = raw.drop(nctrls).keep(nctrls).indicesOfEqual(1) ? [];
        var btns = raw.drop(2 * nctrls).keep(nfxs).indicesOfEqual(1) ? [];
        var leftRightMute = raw.drop((2 * nctrls) + nfxs).indicesOfEqual(1) ? [];
        var data = (
            mute: leftRightMute.includes(muteBtn),
            left: leftRightMute.includes(leftBtn),
            right: leftRightMute.includes(rightBtn),
            idxs: btns,
            ctrls: if (ctrls != oldCtrls, { ctrls }, { nil });
        );

        oldCtrls = ctrls;
        data;
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
