#!/usr/bin/env python3
import argparse
import json
import random
import threading
import time

import paho.mqtt.client as mqtt

SENSORS = [
    ("temperature", "°C", 10.0, 40.0),
    ("humidity", "%", 20.0, 80.0),
]


def make_client(client_id):
    try:
        return mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION1,
            client_id=client_id,
            protocol=mqtt.MQTTv311,
        )
    except (AttributeError, TypeError):
        return mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv311)


def publish_device(broker, port, device_id, rate_hz, duration_s, qos, stats):
    client = make_client(f"load-{device_id}")
    client.reconnect_delay_set(min_delay=1, max_delay=5)
    try:
        client.connect(broker, port, keepalive=60)
    except Exception as exc:
        print(f"[{device_id}] spajanje neuspješno: {exc}")
        stats["errors"] += 1
        return
    client.loop_start()

    interval = 1.0 / rate_hz
    counter = 0
    end_time = time.time() + duration_s
    pending = []

    while time.time() < end_time:
        cycle_start = time.time()
        for sensor, unit, lo, hi in SENSORS:
            counter += 1
            now_ms = int(time.time() * 1000)
            msg_id = f"{device_id}-{now_ms}-{counter}"
            topic = f"telemetry/{device_id}/{sensor}"
            payload = json.dumps({
                "msg_id": msg_id,
                "device_id": device_id,
                "sensor": sensor,
                "value": round(random.uniform(lo, hi), 1),
                "unit": unit,
                "timestamp": now_ms,
            })
            info = client.publish(topic, payload, qos=qos)
            if info.rc == mqtt.MQTT_ERR_SUCCESS:
                pending.append((info, msg_id))
            else:
                stats["errors"] += 1
        sleep = interval - (time.time() - cycle_start)
        if sleep > 0:
            time.sleep(sleep)

    for info, msg_id in pending:
        try:
            try:
                info.wait_for_publish(timeout=15)
            except TypeError:
                info.wait_for_publish()
        except (ValueError, RuntimeError):
            stats["errors"] += 1
            continue
        if info.is_published():
            stats["published"] += 1
            stats["ids"].append(msg_id)
        else:
            stats["errors"] += 1

    client.loop_stop()
    client.disconnect()


def main():
    parser = argparse.ArgumentParser(description="Generator opterećenja IoT telemetrije")
    parser.add_argument("--broker", default="localhost")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--devices", type=int, default=5)
    parser.add_argument("--rate", type=float, default=1.0,
                        help="poruka/s po uređaju po ciklusu senzora")
    parser.add_argument("--duration", type=int, default=30, help="trajanje u sekundama")
    parser.add_argument("--qos", type=int, default=1, choices=[0, 1, 2])
    parser.add_argument("--prefix", default="virtual",
                        help="prefiks device_id, npr. virtual -> virtual-001")
    parser.add_argument("--id-log", default=None,
                        help="zapiši svaki potvrđeni msg_id u datoteku")
    args = parser.parse_args()

    per_thread_stats = []
    threads = []
    for i in range(args.devices):
        s = {"published": 0, "errors": 0, "ids": []}
        per_thread_stats.append(s)
        device_id = f"{args.prefix}-{i + 1:03d}"
        t = threading.Thread(
            target=publish_device,
            args=(args.broker, args.port, device_id, args.rate,
                  args.duration, args.qos, s),
            daemon=True,
        )
        threads.append(t)

    print(f"Pokrećem {args.devices} uređaja, {args.rate} ciklusa/s, {args.duration}s (QoS {args.qos})")
    start = time.time()
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    elapsed = time.time() - start

    published = sum(s["published"] for s in per_thread_stats)
    errors = sum(s["errors"] for s in per_thread_stats)

    if args.id_log:
        with open(args.id_log, "w", encoding="utf-8") as fh:
            for s in per_thread_stats:
                for msg_id in s["ids"]:
                    fh.write(msg_id + "\n")

    print(f"\nTrajanje:      {elapsed:.1f}s")
    print(f"Objavljeno:    {published}")
    print(f"Greške:        {errors}")
    print(f"Propusnost:    {published / elapsed:.1f} msg/s")


if __name__ == "__main__":
    main()
