package com.iot.alerting.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TelemetryMessage {

    @JsonProperty("msg_id")
    private String msgId;

    @JsonProperty("device_id")
    private String deviceId;

    private String sensor;

    private double value;

    private String unit;

    private long timestamp;
}
