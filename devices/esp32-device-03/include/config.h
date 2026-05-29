#ifndef CONFIG_H
#define CONFIG_H

#define WIFI_SSID     "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

#define MQTT_BROKER   "YOUR_BROKER_IP"
#define MQTT_PORT     1883
#define MQTT_USER     ""
#define MQTT_PASSWORD ""

#define DEVICE_ID     "esp32-003"

#define TOPIC_TEMPERATURE "telemetry/" DEVICE_ID "/temperature"
#define TOPIC_HUMIDITY    "telemetry/" DEVICE_ID "/humidity"

#define DHT_PIN       4
#define DHT_TYPE      DHT11

#define SWITCH_PIN    27
#define LED_PIN       2

#define PUBLISH_INTERVAL_MS 5000

#define MQTT_QOS      1

#define OUTBOX_CAPACITY        256
#define OUTBOX_DRAIN_PER_TICK  5
#define RECONNECT_INTERVAL_MS  5000

#endif
