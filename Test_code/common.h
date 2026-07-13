// common.h – shared definitions for all nodes

#ifndef COMMON_H
#define COMMON_H

#include <esp_now.h>
#include <WiFi.h>

// MAC addresses (set these to your actual ESP32 MAC addresses)
uint8_t broadcastMac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}; // broadcast
uint8_t gatewayMac[]  = {0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX}; // replace with gateway MAC

// Message structure sent from anchor to gateway
typedef struct {
  uint8_t anchorId;      // 0, 1, or 2
  int16_t rssi;          // RSSI value in dBm (signed)
} AnchorReport;

// Message structure sent from mobile (optional payload)
typedef struct {
  uint8_t beaconId;      // just a counter
} BeaconMsg;

#endif