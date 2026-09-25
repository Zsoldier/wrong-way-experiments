# Architecture & Protocol Notes

## Why not a direct API-to-API bridge?

UniFi Access does expose a local controller API (token-based, used by the Home Assistant
`unifi_access` integration) that can *read* door/DPS state and *trigger* the relay to unlock —
but it does not offer a documented way to inject an arbitrary third-party sensor's state as if it
were the hub's own DPS/AUX reading. The hub's DPS/AUX inputs are purpose-built as physical dry
contacts. Rather than fight that, this project treats the Pi as a **protocol translator**: cloud
API state in, dry-contact signal out — the same pattern you'd use to bridge any "smart" sensor
into a legacy alarm panel.

If Ubiquiti later exposes a supported "virtual sensor" API, `relay_controller.py`'s interface
(`set_dps(closed: bool)`, `set_aux(active: bool)`) is intentionally the seam where you'd swap the
GPIO implementation for an HTTP call without touching `monitor.py`'s polling/decision logic.

## Component responsibilities

- **`august_client.py`** — thin wrapper around [`yalexs`](https://github.com/Yale-Libs/yalexs)
  (the library Home Assistant's official August/Yale integration uses). Handles OAuth
  login/token caching and exposes `get_lock_status()` / `get_doorsense_status()`.
- **`relay_controller.py`** — wraps `gpiozero.OutputDevice` for the two relay channels, with an
  `active_high` flag (some relay boards trigger on LOW) and a `pulse()` vs `hold()` mode
  depending on whether the hub wants a momentary or held contact for a given input.
- **`monitor.py`** — the poll loop: fetch state on an interval, debounce transient
  reads (cloud APIs are occasionally flaky), diff against last-known state, and only toggle
  relays on a real state change. Logs every transition for audit purposes.

## Polling interval & rate limiting

August's cloud API is not designed for tight polling. Default interval is 30s
(`poll_interval_seconds` in config). The client also backs off exponentially on repeated auth or
5xx errors to avoid getting rate-limited or flagged.

## State machine (per relay channel)

```
        state changed?
  ┌───────────┐  no   ┌───────────┐
  │  POLL      ├──────►│  SLEEP     │
  └─────┬──────┘       └─────┬──────┘
        │ yes                │ wait poll_interval_seconds
        ▼                    │
  ┌───────────┐              │
  │ DEBOUNCE   │◄─────────────┘
  │ (N consecutive
  │  matching reads)
  └─────┬──────┘
        │ confirmed
        ▼
  ┌───────────┐
  │ DRIVE RELAY│
  │ + log event│
  └───────────┘
```

## Failure modes considered

| Failure | Behavior |
|---|---|
| Pi loses Wi-Fi | Relays hold last known state; monitor logs the outage and retries with backoff |
| August API auth expires | `august_client` attempts re-auth using cached refresh token; if that fails, alerts via log (extend with a notification hook as needed) |
| Relay board loses power | Both channels fail open (no contact) — configure UniFi Access DPS "invert" logic so a *lost* signal reads as a safe/known state rather than silently reporting "door closed" |
| Cloud reports a bad/transient value | Debounce window (default: 2 consecutive matching polls) prevents relay chatter |
