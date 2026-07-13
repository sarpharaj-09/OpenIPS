#ifndef COMMON_H
#define COMMON_H

#include <esp_now.h>
#include <WiFi.h>

// MAC Addresses (from your list)
// IMPORTANT: gatewayMac MUST match the actual MAC address of the physical
// board you flash with the `gateway` environment, or anchors/mobile will
// send packets that nobody receives. See README.md for how to find it.
uint8_t gatewayMac[] = {0x68, 0x09, 0x47, 0x48, 0x72, 0x70};
uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

typedef struct {
  uint8_t anchorId;
  int16_t rssi;
  uint16_t beaconSeq;   // beaconId this RSSI/EMA sample corresponds to,
                          // lets the gateway/PC confirm whether the 3
                          // anchors' latest reports came from the same
                          // (or a close) mobile beacon transmission.
} AnchorReport;

typedef struct {
  uint8_t beaconId;
} BeaconMsg;

#endif