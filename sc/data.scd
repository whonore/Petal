/*
** OneBox
** data.scd
** Wolf Honore
**
** Read sensor data.
*/

// Only execute once
~data_loaded ?? {
    var portName, port, syncVal;

    "common.scd".loadRelative(true);

    // Serial Init
    ~initData = {
        portName = if (~debug.not, { "/dev/ttyACM0" }, { "../ino/tmppty".resolveRelative });
        syncVal = 13; // Special value to mark start of send
        ~dataDelay = 1; // msec to wait between sending data
        port = SerialPort(portName, 9600, crtscts: true);

        port;
    };

    // Read messages from Arduino
    ~readData = {|nfxs, nctrls|
        var mute, leftRight, idxs, ctrl;

        // Wait until syncVal written
        while ({port.read != syncVal}, {});

        mute = port.read;
        leftRight = { port.read } ! 2;
        idxs = { port.read } ! nfxs;

        ctrl = Array.fill(nctrls, {
            var lo = port.read;
            var hi = port.read;
            (hi << 8) | lo;
        }).linlin(0, 1023, 0, 1);

        [mute, leftRight, idxs, ctrl];
    };

    ~data_loaded = true;
};
