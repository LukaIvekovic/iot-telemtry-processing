#ifndef CONFIG_H
#define CONFIG_H

#define WIFI_SSID     "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

#define MQTT_BROKER   "YOUR_BROKER_IP"
#define MQTT_PORT     1883
#define MQTT_USER     ""
#define MQTT_PASSWORD ""

#define DEVICE_ID     "esp32-002"

#define TOPIC_TEMPERATURE "telemetry/" DEVICE_ID "/temperature"
#define TOPIC_HUMIDITY    "telemetry/" DEVICE_ID "/humidity"

#define DHT_PIN       4
#define DHT_TYPE      DHT11

#define BUTTON_PIN    0
#define LED_PIN       2

#define MQTT_QOS      1

#endif
