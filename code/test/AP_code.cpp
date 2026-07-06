/*
 * ESP32 as Access Point for Antenna Testing
 * 
 * Creates a simple Wi-Fi network that the second ESP32 will connect to.
 * No external router required.
 */

#include <WiFi.h>

const char* ssid     = "ESP32_TestAP";
const char* password = "12345678";

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  WiFi.softAP(ssid, password);
  Serial.println("Access Point started");
  Serial.print("SSID: ");
  Serial.println(ssid);
  Serial.print("IP address of AP: ");
  Serial.println(WiFi.softAPIP());
}

void loop() {
  // Nothing to do here – just keep the AP running
  delay(1000);
}