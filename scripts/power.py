#!/bin/env python
"""
Petal
power.py
Wolf Honore

Shutdown the Pi with a button.
"""
import subprocess
from signal import pause

from gpiozero import Button  # type: ignore


def shutdown() -> None:
    subprocess.run(["shutdown", "now"], check=False)


if __name__ == "__main__":
    power_btn = Button(3, pull_up=True)
    power_btn.when_pressed = shutdown
    pause()
