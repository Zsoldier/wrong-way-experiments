# August ⇄ UniFi Door Monitor

Raspberry Pi Zero W service that watches an August/Yale Access smart lock's lock + door-sense
state (via the cloud API) and reflects that state to a **UniFi Access UA Hub Door Mini** by
driving its dry-contact **DPS** (Door Position Sensor) and **AUX** inputs through a GPIO relay
board — plus, optionally, calling the UniFi Access local API directly to log/annotate events.

> Status: experimental / lab project. Not a production access-control system. See
> [Safety & Disclaimer](#safety--disclaimer).

## Why this exists

The UA Hub Door Mini expects **physical dry contacts** for door position (DPS), request-to-exit
(REX), and its auxiliary input (AUX) — it has no concept of "an August lock told me it's locked."
This project bridges that gap: a Pi polls the August cloud API (the same approach Home Assistant's
`yalexs`-based integration uses) and toggles small relays wired into the hub's low-voltage input
terminals so UniFi Access "sees" a normal sensor closure/opening.

## Architecture

```
┌────────────────────┐        HTTPS (OAuth)        ┌────────────────────┐
│  August/Yale cloud  │ ◄─────────────────────────► │   Raspberry Pi     │
│  (lock + doorsense) │        polls every N sec     │   Zero W           │
└────────────────────┘                              │  monitor.py        │
                                                      │  (yalexs client)   │
                                                      └─────────┬──────────┘
                                                                │ GPIO (BCM17/27)
                                                                ▼
                                                      ┌────────────────────┐
                                                      │ 2-channel 3.3V     │
                                                      │ relay module        │
                                                      └─────────┬──────────┘
                                                                │ dry contact closure
                                                                ▼
                                                      ┌────────────────────┐
                                                      │ UA Hub Door Mini    │
                                                      │  DPS (+/-)          │
                                                      │  AUX  (+/-)         │
                                                      └────────────────────┘
```

- **DPS relay** — closed when August Doorsense reports the door is *closed*, open when the door
  is *open* (mirrors a normal magnetic reed switch's NC behavior).
- **AUX relay** — closed when the August lock reports *locked*, open when *unlocked*. This gives
  you a second dry-contact channel in UniFi Access you can alarm/automate on (e.g., "locked but
  door open" state).
- The Pi does **not** control the door strike/lock itself — this is a read-only state mirror.
  Locking/unlocking stays with the August app/Home Assistant.

Full wiring diagram and bill of materials: [`docs/wiring-diagram.md`](docs/wiring-diagram.md)
Design notes and protocol details: [`docs/architecture.md`](docs/architecture.md)

## Repo layout

```
august-unifi-door-monitor/
├── README.md
├── requirements.txt
├── config.example.yaml
├── docs/
│   ├── architecture.md
│   └── wiring-diagram.md
├── src/
│   ├── august_client.py     # yalexs wrapper: auth + poll lock/doorsense state
│   ├── relay_controller.py  # GPIO relay driver (gpiozero)
│   └── monitor.py           # main loop: poll -> debounce -> drive relays
└── systemd/
    └── august-door-monitor.service
```

## Quick start

1. Flash Raspberry Pi OS Lite (Bookworm) on the Zero W, enable SSH.
2. `sudo apt install python3-venv` then create a venv and
   `pip install -r requirements.txt`.
3. Copy `config.example.yaml` → `config.yaml`, fill in August account credentials/lock ID and
   your GPIO pin assignments.
4. Wire the relay module per [`docs/wiring-diagram.md`](docs/wiring-diagram.md).
5. First run: `python3 src/monitor.py --config config.yaml` — it will trigger the
   `yalexs` OAuth device-verification flow (email/SMS code) once, then cache the token.
6. Install as a service: `sudo cp systemd/august-door-monitor.service /etc/systemd/system/` then
   `sudo systemctl enable --now august-door-monitor`.

## Safety & disclaimer

- Only ever use the **dry-contact** terminals (DPS/REX/AUX) with relay isolation — never wire Pi
  GPIO pins directly to the hub's terminals. The relay module provides electrical isolation
  between the Pi's 3.3V logic and the hub's low-voltage sensing circuit.
- This does not replace a certified door-position/REX sensor for life-safety or fire-egress
  purposes. Keep any code-required REX/exit hardware on its own dedicated, compliant wiring.
- August cloud API is unofficial/reverse-engineered (same library Home Assistant uses); it can
  break if August changes their backend.
