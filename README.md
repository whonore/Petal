# Petal
A software effects pedal using SuperCollider

## Configure

- [Configure Pi](https://madskjeldgaard.dk/posts/raspi4-notes/)
```
./scripts/configure_pi
```
- [Install Realtime Kernel](https://github.com/kdoren/linux/wiki/Installation-of-kernel-from-deb-package-%28Raspberry-Pi-OS%29)
- [Install SuperCollider](https://github.com/supercollider/supercollider/blob/develop/README_RASPBERRY_PI.md)
```sh
./scripts/install_sc
```
- Install Arduino libraries
  - [Adafruit_Seesaw >= 1.6.2](https://github.com/adafruit/Adafruit_Seesaw)

## Launch

### Manual

```sh
./scripts/launch
```

### Automatic

```sh
./scripts/install_systemd
```
