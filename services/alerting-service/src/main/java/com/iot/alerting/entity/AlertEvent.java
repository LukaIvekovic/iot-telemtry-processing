package com.iot.alerting.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "alert_events")
public class AlertEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String msgId;

    private String deviceId;

    private String sensor;

    private double value;

    private String ruleName;

    private String severity;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
