#!/usr/bin/env python3
"""Main poll loop: August cloud state -> debounce -> drive UA Hub Door Mini relays.

Usage:
    python3 monitor.py --config config.yaml
"""
from __future__ import annotations

import argparse
import asyncio
import logging
from collections import deque
from typing import Deque, Optional

import yaml

from august_client import AugustClient, LockState
from relay_controller import RelayController

log = logging.getLogger("monitor")


def load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def setup_logging(cfg: dict) -> None:
    logging.basicConfig(
        level=getattr(logging, cfg.get("level", "INFO").upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(cfg.get("file", "monitor.log")),
        ],
    )


class Debouncer:
    """Requires N consecutive matching readings before treating a value as confirmed."""

    def __init__(self, required: int) -> None:
        self._required = required
        self._history: Deque[Optional[bool]] = deque(maxlen=required)
        self._confirmed: Optional[bool] = None

    def feed(self, value: Optional[bool]) -> Optional[bool]:
        self._history.append(value)
        if len(self._history) == self._required and all(v == value for v in self._history) and value is not None:
            self._confirmed = value
        return self._confirmed


async def run(config_path: str) -> None:
    cfg = load_config(config_path)
    setup_logging(cfg.get("logging", {}))

    august_cfg = cfg["august"]
    poll_cfg = cfg.get("polling", {})
    gpio_cfg = cfg["gpio"]

    client = AugustClient(
        login_method=august_cfg["login_method"],
        username=august_cfg["username"],
        password=august_cfg["password"],
        lock_name=august_cfg["lock_name"],
        install_id=august_cfg.get("install_id"),
        token_cache_file=august_cfg.get("token_cache_file", "august_token_cache.json"),
    )

    relays = RelayController(
        dps_pin=gpio_cfg["dps_relay_pin"],
        aux_pin=gpio_cfg["aux_relay_pin"],
        active_high=gpio_cfg.get("active_high", False),
        door_sensor_pin=gpio_cfg.get("door_sensor_pin"),
        door_sensor_pull_up=gpio_cfg.get("door_sensor_pull_up", True),
    )

    interval = poll_cfg.get("interval_seconds", 30)
    debounce_n = max(1, poll_cfg.get("debounce_reads", 2))
    backoff_max = poll_cfg.get("backoff_max_seconds", 300)

    lock_debounce = Debouncer(debounce_n)
    door_debounce = Debouncer(debounce_n)

    backoff = interval
    try:
        await client.authenticate()
        while True:
            try:
                state: LockState = await client.get_state()
                backoff = interval  # reset backoff after a healthy poll

                confirmed_locked = lock_debounce.feed(state.is_locked)
                confirmed_door_closed = door_debounce.feed(state.is_door_closed)

                if confirmed_locked is not None:
                    relays.set_aux(locked=confirmed_locked)
                if confirmed_door_closed is not None:
                    relays.set_dps(door_closed=confirmed_door_closed)

                physical = relays.read_physical_door_sensor()
                if physical is not None and confirmed_door_closed is not None and physical != confirmed_door_closed:
                    log.warning(
                        "Cross-check mismatch: August Doorsense reports door_closed=%s but physical "
                        "sensor reports door_closed=%s",
                        confirmed_door_closed,
                        physical,
                    )

            except Exception:
                log.exception("Poll failed; backing off for %ss", backoff)
                await asyncio.sleep(backoff)
                backoff = min(backoff * 2, backoff_max)
                continue

            await asyncio.sleep(interval)
    finally:
        relays.close()
        await client.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="config.yaml", help="Path to config.yaml")
    args = parser.parse_args()
    asyncio.run(run(args.config))


if __name__ == "__main__":
    main()
