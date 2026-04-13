package com.iot.alerting.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;

@Data
@Configuration
@ConfigurationProperties(prefix = "alerting")
public class AlertRulesConfig {

    private List<AlertRule> rules = new ArrayList<>();

    @Data
    public static class AlertRule {
        private String sensor;
        private double min;
        private double max;
    }
}
