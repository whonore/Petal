/*
** OneBox
** loadFxs.scd
** Wolf Honore
**
** Load all fxs.
*/

(
var fxOrder = [
    \distortion,
    \tremolo,
    \chorus,
    \octaver,
    \freeVerb,
    \algVerb,
    \conVerb,
    \wah,
    \loop,
    \reverse,
    \radio,
    \bendy
];

// Load all fxs and get the mappings from fxName to ControlSpecs
var fxCtrls = IdentityDictionary.with(*"*/*.scd".resolveRelative.loadPaths(true, {|fx|
    ("Loading " + fx).postln;
}));

// Order by fxOrder
var fxs = fxOrder.select {|fxName| fxCtrls.includesKey(fxName); };

// If unspecified order, sort alphabetically
var unsorted = (fxCtrls.keys - fxOrder.asSet).asArray.sort;
unsorted.do {|fxName|
    (fxName.asString ++ "'s order is not specified. Defaulting to alphabetic.").warn;
};

// Return pair of map from fx -> list controls and ordered list of fx
[fxCtrls, fxs ++ unsorted];
)
