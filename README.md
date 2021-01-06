# Petal
A software effects pedal using Supercollider

Start jack: `jackd -r -dalsa -P hw:PCH -C hw:PCH -r44100 -p1024 -n2`
-R for realtime
`aplay/arecord -l` to list output/input devices

Start fake serial device:
`ino/fake_readdata [rand | read]`
