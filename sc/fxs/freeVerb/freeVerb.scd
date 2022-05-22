/*
** Petal
** freeVerb.scd
** Wolf Honore
**
** The FreeVerb Ugen. Included for comparison with other reverbs.
*/

(
var fxName = \freeVerb;

"../../common.scd".loadRelative(true);

~makeFx.value(fxName, {|in, mix=0.33, size=0.5|
    // mix [0, 1]: Dry/wet balance
    // size [0, 1]: Size of the room
    FreeVerb.ar(in, mix, size);
});

fxName -> [
    \mix -> ControlSpec(0, 1, step: 0.01, default: 0.33, units: \pct),
    \size -> ControlSpec(0, 1, step: 0.05, default: 0.5, units: \pct)
];
)
