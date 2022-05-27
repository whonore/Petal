# Petal
A software effects pedal using SuperCollider

[Install SuperCollider](https://github.com/supercollider/supercollider/blob/develop/README_RASPBERRY_PI.md)
[Configure Pi](https://madskjeldgaard.dk/posts/raspi4-notes/)

Start jack: `jackd -r -dalsa -P hw:PCH -C hw:PCH -r44100 -p1024 -n2`
-R for realtime
`aplay/arecord -l` to list output/input devices
