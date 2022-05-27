#!/bin/env python
"""
Petal
set_led.py
Wolf Honore

Turn the button LEDs on or off.
"""
import sys

from gpiozero import LED  # type: ignore
from gpiozero.pins.rpigpio import RPiGPIOFactory, RPiGPIOPin  # type: ignore


# Hack to prevent resetting LED state on exit
# See: https://github.com/gpiozero/gpiozero/issues/707
def _close(_self):
    pass


RPiGPIOPin.close = _close

PINS = (26, 19, 13, 6)
LEDS = [LED(pin, initial_value=None, pin_factory=RPiGPIOFactory()) for pin in PINS]


def set_led(idx: int, state: bool) -> None:
    LEDS[idx].value = state


if __name__ == "__main__":
    states = [bool(int(x)) for x in sys.argv[1:]]
    for idx, state in enumerate(states):
        set_led(idx, state)
