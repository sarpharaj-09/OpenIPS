#ifndef COMMON_H
#define COMMON_H

#include <esp_now.h>
#include <WiFi.h>

// MAC Addresses (from your list)
uint8_t gatewayMac[] = {0x68, 0x09, 0x47, 0x48, 0x72, 0x70};
uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

typedef struct {
  uint8_t anchorId;
  int16_t rssi;
} AnchorReport;

typedef struct {
  uint8_t beaconId;
} BeaconMsg;

#endif