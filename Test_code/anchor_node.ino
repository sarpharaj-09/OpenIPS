// anchor_node.ino – receives beacon, forwards RSSI to gateway

#include "common.h"
#include <esp_now.h>
#include <WiFi.h>

// Set unique ID for each anchor (0,1,2)
#define ANCHOR_ID  0   // change to 1 or 2 for other anchors

uint8_t gatewayMac[] = {0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX}; // same as in common.h

// Callback when a packet is received
void onDataRecv(const uint8_t *mac, const uint8_t *incomingData, int len) {
  // We only care about mobile beacon (you can check if mac is mobile's)
  BeaconMsg beacon;
  memcpy(&beacon, incomingData, sizeof(beacon));
  
  // Get RSSI of this received packet (ESP-NOW stores it in esp_now_recv_info_t)
  // In newer API, we can obtain RSSI via the callback parameters.
  // We'll use a global variable set in the callback.
  // (For simplicity, we assume callback provides rssi via esp_now_recv_info_t)
  // Actually, we need to use the new callback signature:
  // void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len)
  // We'll implement that.
}

// The actual callback with RSSI:
void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *incomingData, int len) {
  // info->src_addr is sender MAC, info->rssi is the RSSI
  BeaconMsg beacon;
  memcpy(&beacon, incomingData, sizeof(beacon));
  
  // Build report to gateway
  AnchorReport report;
  report.anchorId = ANCHOR_ID;
  report.rssi = info->rssi;    // RSSI in dBm
  
  // Send to gateway
  esp_now_send(gatewayMac, (uint8_t *)&report, sizeof(report));
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init failed");
    return;
  }
  
  // Register receive callback (with RSSI support)
  esp_now_register_recv_cb(onDataRecv);
  
  // Add gateway as peer
  esp_now_peer_info_t peerInfo;
  memcpy(peerInfo.peer_addr, gatewayMac, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add gateway peer");
    return;
  }
  
  // Also add broadcast peer (optional – to receive beacons, we don't need to add broadcast)
  // Actually, to receive broadcast, we don't need to add a peer; just register recv cb.
}

void loop() {
  // Nothing else needed – everything is event-driven
}