# Petal
A software effects pedal using SuperCollider

- [Install SuperCollider](https://github.com/supercollider/supercollider/blob/develop/README_RASPBERRY_PI.md)
- [Configure Pi](https://madskjeldgaard.dk/posts/raspi4-notes/)
- Install Arduino libraries
  - [Adafruit_Seesaw >= 1.6.2](https://github.com/adafruit/Adafruit_Seesaw)
- Set activity light to GPIO4
```
# /boot/config.txt
...
dtparam=act_led_gpio=4
```
- Launch
```sh
./scripts/launch
```
