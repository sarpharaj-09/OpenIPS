// src/main.cpp – Unified code for all nodes

#include "common.h"
#include <esp_now.h>
#include <WiFi.h>
#include <math.h>   // for fabsf() used in anchor outlier rejection

// Ensure we're using Arduino-ESP32 core 3.x for esp_now_recv_info_t support
#if ESP_ARDUINO_VERSION_MAJOR < 3
#error "Real ESP-NOW RSSI requires Arduino-ESP32 core 3.x (IDF 5.x). \
Update platformio.ini to use the pioarduino platform (see platformio.ini comments)."
#endif

// --------------------------------------------------------
// 1. MOBILE NODE CODE
// --------------------------------------------------------
#ifdef NODE_ROLE_MOBILE

BeaconMsg beaconData;
unsigned long lastSend = 0;
const unsigned long SEND_INTERVAL = 100;

void onDataSent(const wifi_tx_info_t *tx_info, esp_now_send_status_t status) {
  Serial.print("[MOBILE] Send status: ");
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "OK" : "FAIL");
}

void setup_mobile() {
  Serial.begin(115200);
  delay(300);
  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) {
    Serial.println("[MOBILE] ERROR: ESP-NOW init failed.");
    return;
  }
  esp_now_register_send_cb(onDataSent);

  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, broadcastMac, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  peerInfo.ifidx = WIFI_IF_STA;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("[MOBILE] ERROR: Failed to add broadcast peer.");
    return;
  }

  beaconData.beaconId = 0;
}

void loop_mobile() {
  if (millis() - lastSend >= SEND_INTERVAL) {
    if (esp_now_send(broadcastMac, (uint8_t *)&beaconData, sizeof(beaconData)) != ESP_OK) {
      Serial.println("[MOBILE] ERROR: Send failed.");
    }
    beaconData.beaconId++;
    lastSend = millis();
  }
}

#endif // MOBILE

// --------------------------------------------------------
// 2. ANCHOR NODE CODE
// --------------------------------------------------------
#ifdef NODE_ROLE_ANCHOR

const int16_t ANCHOR_READY_RSSI = 32767;
const int16_t RSSI_UNAVAILABLE = -127;
const unsigned long READY_HEARTBEAT_MS = 2000;
unsigned long lastReadyHeartbeat = 0;

// --- EMA smoothing state ---
// Lower EMA_ALPHA = smoother but laggier response to mobile movement.
// Higher EMA_ALPHA = more responsive but noisier. Tune from real grid data;
// 0.3 is a reasonable starting point.
const float EMA_ALPHA = 0.3f;
float smoothedRssi = 0.0f;
bool firstSample = true;

// --- Outlier rejection ---
// Reject a raw sample if it jumps more than this many dB away from the
// current smoothed value in one packet. Guards against stray multipath
// spikes corrupting the average. Only active once firstSample is false,
// so it never blocks the very first real reading.
const float OUTLIER_THRESHOLD_DB = 15.0f;

uint16_t lastBeaconSeq = 0;

void sendAnchorReadyHeartbeat() {
  AnchorReport readyReport;
  readyReport.anchorId = ANCHOR_ID;
  readyReport.rssi = ANCHOR_READY_RSSI;
  readyReport.beaconSeq = 0;
  esp_now_send(gatewayMac, (uint8_t *)&readyReport, sizeof(readyReport));
}

void onDataRecv_anchor(const esp_now_recv_info_t *info, const uint8_t *incomingData, int len) {
  if (len != sizeof(BeaconMsg)) return;

  BeaconMsg incoming;
  memcpy(&incoming, incomingData, sizeof(incoming));
  lastBeaconSeq = incoming.beaconId;

  int16_t rawRssi = (info->rx_ctrl != nullptr) ? info->rx_ctrl->rssi : RSSI_UNAVAILABLE;

  AnchorReport report;
  report.anchorId = ANCHOR_ID;   // <-- This comes from build flag!
  report.beaconSeq = lastBeaconSeq;

  if (rawRssi == RSSI_UNAVAILABLE) {
    // Can't smooth what we don't have — pass the sentinel straight through
    // so the gateway can still tell "packet received, no RSSI support".
    report.rssi = RSSI_UNAVAILABLE;
  } else if (firstSample) {
    smoothedRssi = (float)rawRssi;
    firstSample = false;
    report.rssi = rawRssi;
  } else if (fabsf((float)rawRssi - smoothedRssi) > OUTLIER_THRESHOLD_DB) {
    // Likely a multipath spike / bad packet — skip updating the average,
    // but still report the last-known-good smoothed value so the gateway
    // doesn't see a gap.
    report.rssi = (int16_t)smoothedRssi;
  } else {
    smoothedRssi = EMA_ALPHA * (float)rawRssi + (1.0f - EMA_ALPHA) * smoothedRssi;
    report.rssi = (int16_t)smoothedRssi;
  }

  esp_now_send(gatewayMac, (uint8_t *)&report, sizeof(report));
}

void setup_anchor() {
  Serial.begin(115200);
  delay(300);
  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) {
    Serial.println("[ANCHOR] ERROR: ESP-NOW init failed.");
    return;
  }
  esp_now_register_recv_cb(onDataRecv_anchor);

  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, gatewayMac, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  peerInfo.ifidx = WIFI_IF_STA;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("[ANCHOR] ERROR: Failed to add gateway peer.");
    return;
  }

  // Send once at boot so gateway can confirm this anchor is online.
  sendAnchorReadyHeartbeat();
  lastReadyHeartbeat = millis();
}

void loop_anchor() {
  if (millis() - lastReadyHeartbeat >= READY_HEARTBEAT_MS) {
    sendAnchorReadyHeartbeat();
    lastReadyHeartbeat = millis();
  }
  delay(20);
}

#endif // ANCHOR

// --------------------------------------------------------
// 3. GATEWAY NODE CODE
// --------------------------------------------------------
#ifdef NODE_ROLE_GATEWAY

int16_t rssiValues[3] = {-100, -100, -100};
uint16_t beaconSeqValues[3] = {0, 0, 0};
bool receivedFlags[3] = {false, false, false};
unsigned long lastPacketTime[3] = {0};
const unsigned long TIMEOUT = 200;
const unsigned long STATUS_INTERVAL = 1000;
const unsigned long MOBILE_TIMEOUT = 1500;
const int16_t ANCHOR_READY_RSSI = 32767;
const int16_t RSSI_UNAVAILABLE = -127;
unsigned long lastStatusPrint = 0;
bool anchorReady[3] = {false, false, false};
unsigned long lastMobileActivity = 0;

void handleGatewayReport(const AnchorReport &report) {
  if (report.anchorId >= 3) return;

  if (report.rssi == ANCHOR_READY_RSSI) {
    if (!anchorReady[report.anchorId]) {
      anchorReady[report.anchorId] = true;
      Serial.print("[GW] Anchor ");
      Serial.print(report.anchorId);
      Serial.println(" connected to gateway and ready to share data.");
    }
    return;
  }

  if (report.rssi == RSSI_UNAVAILABLE) {
    anchorReady[report.anchorId] = true;
    receivedFlags[report.anchorId] = true;
    lastPacketTime[report.anchorId] = millis();
    lastMobileActivity = millis();

    Serial.print("[RX] Anchor ");
    Serial.print(report.anchorId);
    Serial.println(" mobile packet received, but RSSI is unavailable on this Arduino core.");
    return;
  }

  anchorReady[report.anchorId] = true;
  rssiValues[report.anchorId] = report.rssi;
  beaconSeqValues[report.anchorId] = report.beaconSeq;
  receivedFlags[report.anchorId] = true;
  lastPacketTime[report.anchorId] = millis();
  lastMobileActivity = millis();

  Serial.print("[RX] Anchor ");
  Serial.print(report.anchorId);
  Serial.print(" RSSI=");
  Serial.print(report.rssi);
  Serial.print(" seq=");
  Serial.println(report.beaconSeq);
}

void onDataRecv_gateway(const esp_now_recv_info_t *info, const uint8_t *incomingData, int len) {
  if (len != sizeof(AnchorReport)) return;

  AnchorReport report;
  memcpy(&report, incomingData, sizeof(report));

  handleGatewayReport(report);
}

void setup_gateway() {
  Serial.begin(115200);
  delay(300);

  Serial.println();
  Serial.println("[GW] Booting gateway...");
  WiFi.mode(WIFI_STA);

  if (esp_now_init() != ESP_OK) {
    Serial.println("[GW] ERROR: ESP-NOW init failed. Gateway not ready.");
    while (true) {
      delay(1000);
    }
  }

  esp_now_register_recv_cb(onDataRecv_gateway);

  Serial.println("[GW] ESP-NOW initialized.");
  Serial.println("[GW] READY: Waiting for anchor reports...");
  Serial.println("[GW] Full output requires 3 fresh anchors (0,1,2).");
}

void loop_gateway() {
  unsigned long now = millis();
  bool allFresh = true;
  int freshCount = 0;

  for (int i = 0; i < 3; i++) {
    bool isFresh = receivedFlags[i] && (now - lastPacketTime[i] <= TIMEOUT) && (rssiValues[i] != RSSI_UNAVAILABLE);
    if (!isFresh) {
      allFresh = false;
    } else {
      freshCount++;
    }
  }

  if (now - lastStatusPrint >= STATUS_INTERVAL) {
    lastStatusPrint = now;

    Serial.print("[GW] Status: ");
    Serial.print(freshCount);
    Serial.println("/3 anchors fresh");

    bool mobileWorking = (lastMobileActivity != 0) && (now - lastMobileActivity <= MOBILE_TIMEOUT);
    Serial.print("[GW] Mobile node: ");
    Serial.println(mobileWorking ? "WORKING" : "NOT WORKING");

    for (int i = 0; i < 3; i++) {
      bool hasRecentPacket = receivedFlags[i] && (now - lastPacketTime[i] <= TIMEOUT);
      bool isFresh = hasRecentPacket && (rssiValues[i] != RSSI_UNAVAILABLE);
      Serial.print("  Anchor ");
      Serial.print(i);
      Serial.print(": ");
      if (!anchorReady[i]) {
        Serial.println("NOT CONNECTED");
      } else if (hasRecentPacket && rssiValues[i] == RSSI_UNAVAILABLE) {
        Serial.println("CONNECTED, MOBILE RX OK, RSSI UNSUPPORTED (Arduino-ESP32 2.x)");
      } else if (isFresh) {
        Serial.print("CONNECTED, RSSI=");
        Serial.println(rssiValues[i]);
      } else if (receivedFlags[i]) {
        Serial.print("CONNECTED, DATA STALE (");
        Serial.print(now - lastPacketTime[i]);
        Serial.println(" ms)");
      } else {
        Serial.println("CONNECTED, WAITING FOR MOBILE DATA");
      }
    }
  }

  if (allFresh) {
    // Format: [GW] CSV: <millis>,<rssi0>,<seq0>,<rssi1>,<seq1>,<rssi2>,<seq2>
    // millis() gives a monotonic timestamp for dt calculations downstream
    // (e.g. Kalman filter). Per-anchor beaconSeq lets the PC-side pipeline
    // confirm whether the three readings correspond to the same (or a
    // close) mobile beacon transmission before trusting the row.
    Serial.print("[GW] CSV: ");
    Serial.print(now);
    Serial.print(",");
    Serial.print(rssiValues[0]);
    Serial.print(",");
    Serial.print(beaconSeqValues[0]);
    Serial.print(",");
    Serial.print(rssiValues[1]);
    Serial.print(",");
    Serial.print(beaconSeqValues[1]);
    Serial.print(",");
    Serial.print(rssiValues[2]);
    Serial.print(",");
    Serial.println(beaconSeqValues[2]);

    for (int i = 0; i < 3; i++) receivedFlags[i] = false;
  }
  delay(10);
}

#endif // GATEWAY

// --------------------------------------------------------
// 4. MAIN SETUP() AND LOOP() – Route to the right code
// --------------------------------------------------------
void setup() {
  #ifdef NODE_ROLE_MOBILE
    setup_mobile();
  #elif NODE_ROLE_ANCHOR
    setup_anchor();
  #elif NODE_ROLE_GATEWAY
    setup_gateway();
  #else
    #error "No NODE_ROLE defined!"
  #endif
}

void loop() {
  #ifdef NODE_ROLE_MOBILE
    loop_mobile();
  #elif NODE_ROLE_ANCHOR
    loop_anchor();
  #elif NODE_ROLE_GATEWAY
    loop_gateway();
  #endif
}