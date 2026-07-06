/*
 * ESP32 as Station – Measures RSSI from a dedicated Access Point
 * 
 * Connects to "ESP32_TestAP" and logs RSSI with a running average.
 * Use this to compare your built‑in antenna vs. custom antenna.
 */

#include <WiFi.h>

// ========== CONFIGURATION ==========
const char* ssid     = "ESP32_TestAP";
const char* password = "12345678";

const unsigned long MEASURE_INTERVAL_MS = 1000;  // read RSSI every second
const int AVERAGE_WINDOW = 10;                   // number of samples for average
// ====================================

float rssiBuffer[AVERAGE_WINDOW];
int bufferIndex = 0;
int readingsCount = 0;
unsigned long lastMeasureTime = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\nESP32 RSSI Logger – Router‑free mode");
  Serial.print("Connecting to ");
  Serial.print(ssid);
  
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to AP!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  Serial.println("Starting RSSI measurements...\n");
  Serial.println("Time(s)\tRSSI(dBm)\tAvg(dBm)");
}

void loop() {
  unsigned long now = millis();
  
  if (now - lastMeasureTime >= MEASURE_INTERVAL_MS) {
    lastMeasureTime = now;
    
    // Read current RSSI (signal strength from the AP)
    long rssi = WiFi.RSSI();
    
    // Store in circular buffer
    rssiBuffer[bufferIndex] = rssi;
    bufferIndex = (bufferIndex + 1) % AVERAGE_WINDOW;
    if (readingsCount < AVERAGE_WINDOW) readingsCount++;
    
    // Calculate average
    float sum = 0;
    for (int i = 0; i < readingsCount; i++) {
      sum += rssiBuffer[i];
    }
    float avgRssi = sum / readingsCount;
    
    // Print timestamp (seconds), raw RSSI, and average
    unsigned long seconds = now / 1000;
    Serial.print(seconds);
    Serial.print("\t");
    Serial.print(rssi);
    Serial.print("\t\t");
    Serial.println(avgRssi, 1);
  }
}