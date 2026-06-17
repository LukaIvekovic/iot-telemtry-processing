package com.iot.alerting.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iot.alerting.config.AlertRulesConfig;
import com.iot.alerting.config.AlertRulesConfig.AlertRule;
import com.iot.alerting.dto.TelemetryMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class AlertingService {

    private static final Logger log = LoggerFactory.getLogger(AlertingService.class);

    private final DeduplicationService deduplicationService;
    private final AlertRulesConfig alertRulesConfig;
    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    public AlertingService(DeduplicationService deduplicationService,
                           AlertRulesConfig alertRulesConfig,
                           NotificationService notificationService,
                           ObjectMapper objectMapper) {
        this.deduplicationService = deduplicationService;
        this.alertRulesConfig = alertRulesConfig;
        this.notificationService = notificationService;
        this.objectMapper = objectMapper;
    }

    public boolean processMessage(String topic, String payload) {
        TelemetryMessage message;
        try {
            message = objectMapper.readValue(payload, TelemetryMessage.class);
        } catch (Exception e) {
            log.error("[Alerting] Discarding unparseable message from topic={}: {}", topic, e.getMessage());
            return true;
        }

        try {
            if (deduplicationService.isDuplicate(message.getMsgId())) {
                log.info("[Dedup] Duplicate msg_id={}, discarding", message.getMsgId());
                return true;
            }

            AlertRule matchingRule = alertRulesConfig.getRules().stream()
                    .filter(rule -> rule.getSensor().equalsIgnoreCase(message.getSensor()))
                    .findFirst()
                    .orElse(null);

            if (matchingRule == null) {
                deduplicationService.markProcessed(message.getMsgId());
                return true;
            }

            if (message.getValue() < matchingRule.getMin() || message.getValue() > matchingRule.getMax()) {
                String severity = determineSeverity(message.getValue(), matchingRule);
                notificationService.fireAlert(message, matchingRule, severity);
            }

            deduplicationService.markProcessed(message.getMsgId());

            log.info("[Alerting] Processed msg_id={} device={} sensor={} value={}",
                    message.getMsgId(), message.getDeviceId(), message.getSensor(), message.getValue());
            return true;

        } catch (Exception e) {
            log.error("[Alerting] Transient failure for msg_id={}, leaving unacknowledged for redelivery: {}",
                    message.getMsgId(), e.getMessage());
            return false;
        }
    }

    private String determineSeverity(double value, AlertRule rule) {
        double range = rule.getMax() - rule.getMin();
        double threshold = range * 0.1;

        if (value < rule.getMin() - threshold || value > rule.getMax() + threshold) {
            return "CRITICAL";
        }
        return "WARNING";
    }
}
