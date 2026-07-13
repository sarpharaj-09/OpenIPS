# OpenIPS Firmware — Flashing Guide

This folder contains the unified PlatformIO firmware for all five ESP32 nodes in the OpenIPS RSSI-based indoor positioning system. A single `src/main.cpp` compiles into **five different binaries** depending on which PlatformIO environment you build — the node's role (`gateway`, `anchor`, or `mobile`) and ID are baked in at compile time via build flags, not chosen at runtime.

## Node roles

| Node | PlatformIO env | Role |
|---|---|---|
| Gateway | `gateway` | Collects RSSI reports from all 3 anchors and prints CSV over serial |
| Anchor 0 | `anchor0` | Fixed reference node, reports RSSI of mobile's beacon to gateway |
| Anchor 1 | `anchor1` | Same as above, `ANCHOR_ID=1` |
| Anchor 2 | `anchor2` | Same as above, `ANCHOR_ID=2` |
| Mobile | `mobile` | Broadcasts a beacon packet every 100 ms for anchors to measure |

You need **5 separate ESP32 boards**, each flashed with its own environment. Flashing the wrong environment onto a board (e.g. `anchor0` and `anchor1` onto two different boards but forgetting to change one) will make trilateration silently report a duplicate anchor ID.

## Prerequisites

- [PlatformIO](https://platformio.org/) — either the VS Code extension or the `pio` CLI (`pip install platformio`)
- 5x ESP32 dev boards (project uses ESP32-WROOM-32U)
- USB-to-UART drivers installed for your board (CP2102/CH340 depending on your dev board)
- All 5 boards on the same Wi-Fi channel (ESP-NOW doesn't need a router, but all peers must be on the same channel — default channel 0/current is fine as long as none of the boards run `WiFi.begin()` elsewhere)

## ⚠️ Before you flash anything: set the gateway's MAC address

`include/common.h` hard-codes the gateway's MAC address:

```cpp
uint8_t gatewayMac[] = {0x68, 0x09, 0x47, 0x48, 0x72, 0x70};
```

This **must** match the actual MAC address of the physical board you're using as the gateway, or anchors/mobile will send packets nobody receives. To find your gateway board's MAC:

1. Flash any board temporarily with a basic sketch containing:
   ```cpp
   void setup() {
     Serial.begin(115200);
     delay(300);
     Serial.println(WiFi.macAddress());
   }
   void loop() {}
   ```
2. Open Serial Monitor, note the printed MAC (format `XX:XX:XX:XX:XX:XX`).
3. Convert it to the `{0x.., 0x.., ...}` byte array format and paste it into `gatewayMac[]` in `include/common.h`.
4. Save — this file is shared by all five environments, so you only need to do this once, and every node will then know how to reach the gateway.

## Set your upload port

`platformio.ini` currently hard-codes `upload_port = COM4` (Windows-style) under `[common]`, which every environment inherits. Update this for your machine before flashing:

- **Windows**: check Device Manager → Ports (COM & LPT) for the COM number, e.g. `COM5`
- **macOS**: usually `/dev/cu.usbserial-XXXX` or `/dev/cu.SLAB_USBtoUART`
- **Linux**: usually `/dev/ttyUSB0` or `/dev/ttyACM0`

Since you're flashing 5 boards one at a time (only one plugged in at a time is easiest), you'll edit this line each time you switch boards — or just omit `upload_port` from `[common]` entirely and let PlatformIO auto-detect the port:

```ini
[common]
platform = https://github.com/pioarduino/platform-espressif32/releases/download/55.03.39/platform-espressif32.zip
board = esp32dev
framework = arduino
monitor_speed = 115200
upload_speed = 460800
; upload_port = COM4   ; comment out to auto-detect
```

## Flashing each node

Open a terminal in this `code/` folder (where `platformio.ini` lives) and run the upload command for one board at a time, unplugging/replugging between boards if you removed `upload_port`.

**Recommended order:** flash the gateway first (so you can watch serial output as you bring up the others), then the anchors, then mobile last.

```bash
# 1. Gateway
pio run -e gateway -t upload

# 2. Anchor 0
pio run -e anchor0 -t upload

# 3. Anchor 1
pio run -e anchor1 -t upload

# 4. Anchor 2
pio run -e anchor2 -t upload

# 5. Mobile
pio run -e mobile -t upload
```

If you're using the VS Code PlatformIO extension instead of the CLI: click the PlatformIO alien icon in the sidebar → under **PROJECT TASKS**, expand the environment you want (`gateway`, `anchor0`, etc.) → **General** → **Upload**. Make sure the correct board is plugged in before clicking.

### Verifying each flash

After uploading, open the serial monitor for that board:

```bash
pio device monitor -b 115200
```

- **Gateway** should print `[GW] Booting gateway...` then `[GW] READY: Waiting for anchor reports...`
- **Anchors** should print `[ANCHOR]`-prefixed lines and start sending heartbeats immediately
- **Mobile** doesn't print much beyond `[MOBILE] Send status: OK` every ~100 ms

Once all 5 boards are powered on, the gateway's serial monitor is your main dashboard — it prints a status line every second showing which anchors are connected/fresh, whether the mobile node is being heard, and (once all 3 anchors report fresh RSSI in the same window) a `[GW] CSV: rssi0,rssi1,rssi2` line you can log or feed into the trilateration filter.

## Common issues

| Symptom | Likely cause |
|---|---|
| `#error "Real ESP-NOW RSSI requires Arduino-ESP32 core 3.x"` at build time | You're not using the pioarduino platform fork — check the `platform =` line in `[common]` wasn't overridden |
| Gateway never shows anchors as connected | `gatewayMac[]` in `common.h` doesn't match the gateway board's real MAC |
| Anchor shows `RSSI UNSUPPORTED (Arduino-ESP32 2.x)` | Stale `.pio` build cache from an older core — run `pio run -t clean` then re-upload |
| Upload fails / times out | Wrong `upload_port`, board not in bootloader mode (hold BOOT button during upload on some boards), or another program (Serial Monitor) has the port open |
| Two anchors report the same `anchorId` | You flashed the same environment (e.g. `anchor0`) onto two different boards by mistake |

## Project structure reference

```
code/
├── platformio.ini      # defines the 5 environments (gateway, anchor0-2, mobile)
├── include/
│   └── common.h         # shared MAC addresses + packet structs — edit gatewayMac here
├── src/
│   └── main.cpp          # unified source, role selected via #ifdef NODE_ROLE_*
└── test/                # early standalone AP/station test sketches (not part of build)
```