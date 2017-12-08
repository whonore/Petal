/*
** OneBox
** freeVerb.scd
** Wolf Honore
*/

(
var fxName = \freeVerb;

"../../common.scd".loadRelative(true);

// Use the FreeVerb Ugen. Included for comparison with other reverbs.
~makeFx.value(fxName, {|in, mix=0.33, size=0.5|
    // mix [0, 1]: Dry/wet balance
    // size [0, 1]: Size of the room
    FreeVerb.ar(in, mix, size);
});

fxName -> [
    \mix -> ControlSpec(0, 1, step: 0.01, default: 0.33),
    \size -> ControlSpec(0, 1, step: 0.05, default: 0.5)
];
)
