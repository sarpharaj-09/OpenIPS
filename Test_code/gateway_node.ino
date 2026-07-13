// gateway_node.ino – collects anchor reports, sends to PC via Serial

#include "common.h"
#include <esp_now.h>
#include <WiFi.h>

// Store latest RSSI from each anchor (initialise with invalid)
int16_t rssiValues[3] = { -100, -100, -100 };
bool receivedFlags[3] = { false, false, false };
unsigned long lastPacketTime[3] = {0};
const unsigned long TIMEOUT = 200; // ms – if no report from an anchor, consider it stale

// Callback when a report arrives from an anchor
void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *incomingData, int len) {
  if (len != sizeof(AnchorReport)) return;
  
  AnchorReport report;
  memcpy(&report, incomingData, sizeof(report));
  
  if (report.anchorId < 3) {
    rssiValues[report.anchorId] = report.rssi;
    receivedFlags[report.anchorId] = true;
    lastPacketTime[report.anchorId] = millis();
  }
}

void setup() {
  Serial.begin(115200);  // to PC
  
  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init failed");
    return;
  }
  
  esp_now_register_recv_cb(onDataRecv);
  
  // Add anchors as peers (optional – we only receive from them, so not strictly needed)
  // But we can add them to enable encryption if needed.
}

void loop() {
  // Check if we have fresh data from all three anchors
  bool allFresh = true;
  for (int i = 0; i < 3; i++) {
    if (!receivedFlags[i] || (millis() - lastPacketTime[i] > TIMEOUT)) {
      allFresh = false;
      break;
    }
  }
  
  if (allFresh) {
    // Send a CSV line: rssi0, rssi1, rssi2
    Serial.print(rssiValues[0]);
    Serial.print(",");
    Serial.print(rssiValues[1]);
    Serial.print(",");
    Serial.println(rssiValues[2]);
    
    // Reset flags to avoid sending duplicate data
    for (int i = 0; i < 3; i++) {
      receivedFlags[i] = false;
    }
  }
  
  // Small delay to prevent busy loop
  delay(10);
}