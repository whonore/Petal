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
    var oldMute, oldLeft, oldRight, oldIdxs, oldCtrls;

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
        var muteRaw, leftRaw, rightRaw, idxsRaw, ctrls;
        var mute, left, right, idxs, changed;

        // Wait until syncVal written
        while ({port.read != syncVal}, {});

        #muteRaw, leftRaw, rightRaw = { port.read } ! 3;
        idxsRaw = { port.read } ! nfxs;

        ctrls = Array.fill(nctrls, {
            var lo = port.read;
            var hi = port.read;
            (hi << 8) | lo;
        }).linlin(0, 1023, 0, 1);

        mute = (muteRaw > (oldMute ? 0));
        left = (leftRaw > (oldLeft ? 0));
        right = (rightRaw > (oldRight ? 0));
        idxs = [idxsRaw, (oldIdxs ? (0 ! nfxs))].flop.collect {|xs| xs[0] > xs[1]};
        changed = (ctrls - (oldCtrls ? (0 ! nctrls))).abs.any(_ > 0);

        oldMute = muteRaw;
        oldLeft = leftRaw;
        oldRight = rightRaw;
        oldIdxs = idxsRaw;
        oldCtrls = ctrls;

        [mute, left, right, idxs, ctrls, changed];
    };

    ~data_loaded = true;
};
