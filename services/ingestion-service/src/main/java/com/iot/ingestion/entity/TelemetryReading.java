package com.iot.ingestion.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "telemetry_readings")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TelemetryReading {

    @Id
    private String msgId;

    private String deviceId;

    private String sensor;

    private double value;

    private String unit;

    private long timestamp;

    @Column(name = "received_at", columnDefinition = "TIMESTAMPTZ")
    private Instant receivedAt;
}
