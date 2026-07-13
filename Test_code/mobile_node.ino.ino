// mobile_node.ino – continuously broadcasts beacons

#include "common.h"
#include <esp_now.h>
#include <WiFi.h>

// Variables
BeaconMsg beaconData;
unsigned long lastSend = 0;
const unsigned long SEND_INTERVAL = 100; // ms

// Callback when message is sent (just for debugging)
void onDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  // Optional: print status
}

void setup() {
  Serial.begin(115200);
  
  // Set WiFi to station mode (required for ESP-NOW)
  WiFi.mode(WIFI_STA);
  
  // Initialize ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init failed");
    return;
  }
  
  // Register send callback
  esp_now_register_send_cb(onDataSent);
  
  // Add broadcast peer (to send to all anchors)
  esp_now_peer_info_t peerInfo;
  memcpy(peerInfo.peer_addr, broadcastMac, 6);
  peerInfo.channel = 0;                // same as WiFi channel
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add broadcast peer");
    return;
  }
  
  beaconData.beaconId = 0;
}

void loop() {
  // Send beacon at fixed interval
  if (millis() - lastSend >= SEND_INTERVAL) {
    esp_err_t result = esp_now_send(broadcastMac, (uint8_t *)&beaconData, sizeof(beaconData));
    if (result == ESP_OK) {
      Serial.println("Beacon sent");
      beaconData.beaconId++;
    } else {
      Serial.println("Beacon send failed");
    }
    lastSend = millis();
  }
}
