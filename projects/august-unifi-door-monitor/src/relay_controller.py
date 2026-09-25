"""GPIO relay driver that mirrors August lock/door state onto the UA Hub Door Mini's
dry-contact DPS and AUX inputs.

Wiring: see docs/wiring-diagram.md. Each relay channel's NO+COM pair is wired across the
corresponding hub terminal pair; energizing the relay closes that contact.
"""
from __future__ import annotations

import logging
from typing import Optional

from gpiozero import OutputDevice

log = logging.getLogger(__name__)


class RelayController:
    def __init__(
        self,
        dps_pin: int,
        aux_pin: int,
        active_high: bool = False,
        door_sensor_pin: Optional[int] = None,
        door_sensor_pull_up: bool = True,
    ) -> None:
        # active_high=False means the relay board energizes the coil on a LOW signal;
        # gpiozero's `active_high` param on OutputDevice matches that same semantic.
        self._dps_relay = OutputDevice(dps_pin, active_high=active_high, initial_value=False)
        self._aux_relay = OutputDevice(aux_pin, active_high=active_high, initial_value=False)

        self._door_sensor = None
        if door_sensor_pin is not None:
            from gpiozero import Button

            self._door_sensor = Button(door_sensor_pin, pull_up=door_sensor_pull_up)

        self._dps_state: Optional[bool] = None
        self._aux_state: Optional[bool] = None

    def set_dps(self, door_closed: bool) -> None:
        """Reflects door-closed state onto the DPS relay contact."""
        if door_closed == self._dps_state:
            return
        self._dps_relay.value = door_closed
        self._dps_state = door_closed
        log.info("DPS relay -> %s (door_closed=%s)", "CLOSED" if door_closed else "OPEN", door_closed)

    def set_aux(self, locked: bool) -> None:
        """Reflects lock state onto the AUX relay contact."""
        if locked == self._aux_state:
            return
        self._aux_relay.value = locked
        self._aux_state = locked
        log.info("AUX relay -> %s (locked=%s)", "CLOSED" if locked else "OPEN", locked)

    def read_physical_door_sensor(self) -> Optional[bool]:
        """Returns True if the optional cross-check reed switch reports door closed, else None
        if not configured. `Button.is_pressed` is True when the circuit is pulled to ground,
        i.e. magnet present / door closed, assuming a normally-open reed switch to GND."""
        if self._door_sensor is None:
            return None
        return self._door_sensor.is_pressed

    def close(self) -> None:
        self._dps_relay.close()
        self._aux_relay.close()
        if self._door_sensor is not None:
            self._door_sensor.close()
