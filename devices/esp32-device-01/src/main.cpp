#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <time.h>
#include "config.h"

WiFiClient   wifiClient;
PubSubClient mqttClient(wifiClient);
DHT          dht(DHT_PIN, DHT_TYPE);

unsigned long lastPublishMs     = 0;
unsigned long lastWifiAttemptMs = 0;
unsigned long lastMqttAttemptMs = 0;
static uint32_t msgCounter = 0;

struct OutboxEntry {
    const char* topic;
    char        payload[256];
};

static OutboxEntry outbox[OUTBOX_CAPACITY];
static size_t outboxHead  = 0;
static size_t outboxTail  = 0;
static size_t outboxCount = 0;

bool switchIsOn() {
    return digitalRead(SWITCH_PIN) == LOW;
}

bool isOnline() {
    return WiFi.status() == WL_CONNECTED && mqttClient.connected();
}

void outboxPush(const char* topic, const char* payload) {
    if (outboxCount == OUTBOX_CAPACITY) {
        outboxHead = (outboxHead + 1) % OUTBOX_CAPACITY;
        outboxCount--;
        Serial.println("[Outbox] FULL — dropping oldest entry");
    }
    outbox[outboxTail].topic = topic;
    strlcpy(outbox[outboxTail].payload, payload, sizeof(outbox[outboxTail].payload));
    outboxTail = (outboxTail + 1) % OUTBOX_CAPACITY;
    outboxCount++;
}

void drainOutbox() {
    if (!isOnline() || outboxCount == 0) return;

    int sent = 0;
    while (sent < OUTBOX_DRAIN_PER_TICK && outboxCount > 0 && isOnline()) {
        OutboxEntry& e = outbox[outboxHead];
        if (!mqttClient.publish(e.topic, e.payload, MQTT_QOS)) {
            break;
        }
        Serial.printf("[Outbox] Replayed → %s  (remaining=%u)\n",
                      e.topic, (unsigned)(outboxCount - 1));
        outboxHead = (outboxHead + 1) % OUTBOX_CAPACITY;
        outboxCount--;
        sent++;
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

void syncNTP() {
    configTime(0, 0, "pool.ntp.org", "time.google.com");
    Serial.print("[NTP] Waiting for time sync");
    struct tm timeInfo;
    while (!getLocalTime(&timeInfo, 10000)) {
        Serial.print(".");
        delay(500);
    }
    Serial.printf("\n[NTP] Time synced: %04d-%02d-%02dT%02d:%02d:%02dZ\n",
        timeInfo.tm_year + 1900, timeInfo.tm_mon + 1, timeInfo.tm_mday,
        timeInfo.tm_hour, timeInfo.tm_min, timeInfo.tm_sec);
}

void attemptWiFi() {
    if (WiFi.status() == WL_CONNECTED) return;
    unsigned long now = millis();
    if (now - lastWifiAttemptMs < RECONNECT_INTERVAL_MS) return;
    lastWifiAttemptMs = now;

    Serial.printf("[WiFi] Reconnect attempt to %s...\n", WIFI_SSID);
    WiFi.disconnect();
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void attemptMQTT() {
    if (WiFi.status() != WL_CONNECTED) return;
    if (mqttClient.connected())        return;
    unsigned long now = millis();
    if (now - lastMqttAttemptMs < RECONNECT_INTERVAL_MS) return;
    lastMqttAttemptMs = now;

    Serial.print("[MQTT] Reconnect attempt... ");
    bool connected = (strlen(MQTT_USER) > 0)
        ? mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASSWORD)
        : mqttClient.connect(DEVICE_ID);
    Serial.printf("%s (rc=%d)\n", connected ? "connected!" : "failed", mqttClient.state());
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
    long long now_ms = (long long)time(nullptr) * 1000LL;
    msgCounter++;
    return String(DEVICE_ID) + "-" + String(now_ms) + "-" + String(msgCounter);
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
    doc["timestamp"] = (long long)time(nullptr) * 1000LL;

    char payload[256];
    serializeJson(doc, payload, sizeof(payload));

    bool ok = false;
    if (isOnline()) {
        ok = mqttClient.publish(topic, payload, MQTT_QOS);
    }

    if (ok) {
        Serial.printf("[MQTT] %s → %s  (QoS %d, sent)\n", topic, payload, MQTT_QOS);
    } else {
        outboxPush(topic, payload);
        Serial.printf("[Outbox] Queued (offline/publish-fail) → %s  (depth=%u)\n",
                      topic, (unsigned)outboxCount);
    }
}

void readAndPublish() {
    digitalWrite(LED_PIN, HIGH);

    float temperature = dht.readTemperature();
    float humidity    = dht.readHumidity();

    if (isnan(temperature) || isnan(humidity)) {
        Serial.println("[DHT] Read failed, skipping publish");
        digitalWrite(LED_PIN, LOW);
        return;
    }

    publishReading(TOPIC_TEMPERATURE, "temperature", temperature, "°C");
    publishReading(TOPIC_HUMIDITY,    "humidity",    humidity,    "%");

    delay(100);
    digitalWrite(LED_PIN, LOW);
}

void setup() {
    Serial.begin(115200);
    Serial.println("\n========================================");
    Serial.println("  ESP32 Device 01 — Temp & Humidity");
    Serial.printf("  Device ID: %s\n", DEVICE_ID);
    Serial.println("========================================\n");

    pinMode(SWITCH_PIN, INPUT_PULLUP);
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    connectWiFi();
    syncNTP();

    mqttClient.setServer(MQTT_BROKER, MQTT_PORT);

    dht.begin();

    Serial.printf("[Ready] Flip the switch ON to publish every %lu ms.\n\n",
                  (unsigned long)PUBLISH_INTERVAL_MS);
}

void loop() {
    attemptWiFi();
    attemptMQTT();
    mqttClient.loop();

    drainOutbox();

    if (switchIsOn()) {
        unsigned long now = millis();
        if (now - lastPublishMs >= PUBLISH_INTERVAL_MS) {
            lastPublishMs = now;
            readAndPublish();
        }
    }
}
