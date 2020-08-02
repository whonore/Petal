/*
** Petal
** data.scd
** Wolf Honore
**
** Read sensor data.
*/

// Only execute once
~data_loaded ?? {
    var portName, port, syncVal;
    var oldCtrls;
    var parseData;
    var muteBtn = 0;
    var leftBtn = 0;
    var rightBtn = 1;

    "common.scd".loadRelative(true);

    // Serial Init
    ~initData = {
        portName = if (~debug.not, { "/dev/ttyS0" }, { "../ino/tmppty".resolveRelative });
        portName = "/dev/ttyS0";
        syncVal = 128; // Special value to mark start of send
        port = SerialPort(portName, 19200, crtscts: true);
        port;
    };

    parseData = {|raw, nctrls|
        var ctrls = raw.keep(nctrls);
        var btns = raw.drop(nctrls).collect {|x| x.indicesOfEqual(1) ? [] };
        var data = (
            mute: btns.includes(nctrls + muteBtn),
            left: btns.includes(leftBtn),
            right: btns.includes(rightBtn),
            idxs: btns.reject {|x| x == 0 },
            ctrls: if (ctrls != oldCtrls, { ctrls.linlin(0, 127, 0, 1) }, { nil });
        );

        oldCtrls = ctrls;
        data;
    };

    // Read messages from Arduino
    ~readData = {|nfxs, nctrls|
        var byte, data;
        var mute, left, right, idxs, ctrls;
        data = List[];

        // Wait until syncVal written
        while ({ port.read != syncVal }, {});
        while ({ byte = port.read; byte != syncVal }, {
            data.add(byte);
        });
        parseData.value(data, nctrls);
    };

    ~data_loaded = true;
};
