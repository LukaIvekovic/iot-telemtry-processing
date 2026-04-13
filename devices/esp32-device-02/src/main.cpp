#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "config.h"

WiFiClient   wifiClient;
PubSubClient mqttClient(wifiClient);

volatile bool buttonPressed = false;
unsigned long lastDebounce  = 0;
const unsigned long DEBOUNCE_MS = 300;
unsigned long messageCounter = 0;

void IRAM_ATTR onButtonPress() {
    unsigned long now = millis();
    if (now - lastDebounce > DEBOUNCE_MS) {
        buttonPressed = true;
        lastDebounce  = now;
    }
}

void connectWiFi() {
    Serial.printf("[WiFi] Connecting to %s ", WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }

    Serial.printf("\n[WiFi] Connected — IP: %s\n", WiFi.localIP().toString().c_str());
}

void connectMQTT() {
    while (!mqttClient.connected()) {
        Serial.print("[MQTT] Connecting to broker... ");

        bool connected = (strlen(MQTT_USER) > 0)
            ? mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASSWORD)
            : mqttClient.connect(DEVICE_ID);

        if (connected) {
            Serial.println("connected!");
        } else {
            Serial.printf("failed (rc=%d). Retrying in 3 s...\n", mqttClient.state());
            delay(3000);
        }
    }
}

String generateMsgId() {
    messageCounter++;
    return String(DEVICE_ID) + "-" + String(millis()) + "-" + String(messageCounter);
}

void publishReading(const char* topic, const char* sensorType,
                    float value, const char* unit) {

    String msgId = generateMsgId();

    JsonDocument doc;
    doc["msg_id"]    = msgId;
    doc["device_id"] = DEVICE_ID;
    doc["sensor"]    = sensorType;
    doc["value"]     = value;
    doc["unit"]      = unit;
    doc["timestamp"] = millis();

    char payload[256];
    serializeJson(doc, payload, sizeof(payload));

    bool ok = mqttClient.publish(topic, payload, MQTT_QOS);

    Serial.printf("[MQTT] %s → %s  (QoS %d, %s)\n",
                  topic, payload, MQTT_QOS, ok ? "sent" : "FAILED");
}

void simulateAndPublish() {
    digitalWrite(LED_PIN, HIGH);

    float temperature = random(180, 350) / 10.0;
    float pressure    = random(9800, 10400) / 10.0;

    publishReading(TOPIC_TEMPERATURE, "temperature", temperature, "°C");
    publishReading(TOPIC_PRESSURE,    "pressure",    pressure,    "hPa");

    delay(100);
    digitalWrite(LED_PIN, LOW);
}

void setup() {
    Serial.begin(115200);
    Serial.println("\n========================================");
    Serial.println("  ESP32 Device 02 — Temp & Pressure");
    Serial.printf("  Device ID: %s\n", DEVICE_ID);
    Serial.println("========================================\n");

    pinMode(BUTTON_PIN, INPUT_PULLUP);
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    attachInterrupt(digitalPinToInterrupt(BUTTON_PIN), onButtonPress, FALLING);

    connectWiFi();
    mqttClient.setServer(MQTT_BROKER, MQTT_PORT);

    randomSeed(analogRead(0) ^ micros());

    Serial.println("[Ready] Press the BOOT button to publish a reading.\n");
}

void loop() {
    if (WiFi.status() != WL_CONNECTED) {
        connectWiFi();
    }
    if (!mqttClient.connected()) {
        connectMQTT();
    }
    mqttClient.loop();

    if (buttonPressed) {
        buttonPressed = false;
        simulateAndPublish();
    }
}
