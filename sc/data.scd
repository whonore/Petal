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
        syncVal = $\n.ascii; // Special value to mark start of send
        port = SerialPort(portName, 19200, crtscts: true);
        port;
    };

    parseData = {|raw, nctrls|
        var encoders, btns, data;
        var parsed = raw.split($ );
        var ctrls = parsed.keep(nctrls).collect {|x| x.asInteger };
        #encoders, btns = parsed.drop(nctrls).collect {|x| x.findAll("1") ? [] };
        data = (
            mute: btns.includes(muteBtn),
            left: encoders.includes(leftBtn),
            right: encoders.includes(rightBtn),
            idxs: btns.reject {|x| x == 0 },
            ctrls: if (ctrls != oldCtrls, { ctrls }, { nil });
        );

        oldCtrls = ctrls;
        data;
    };

    // Read messages from Arduino
    ~readData = {|nfxs, nctrls|
        var byte, data;
        var mute, left, right, idxs, ctrls;
        data = "";

        // Wait until syncVal written
        while ({ port.read != syncVal }, {});
        while ({ byte = port.read; byte != syncVal }, {
            data = data ++ byte.asAscii;
        });
        parseData.value(data, nctrls);
    };

    ~data_loaded = true;
};
