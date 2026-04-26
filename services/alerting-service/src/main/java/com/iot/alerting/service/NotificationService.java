package com.iot.alerting.service;

import com.iot.alerting.config.AlertRulesConfig.AlertRule;
import com.iot.alerting.dto.TelemetryMessage;
import com.iot.alerting.entity.AlertEvent;
import com.iot.alerting.repository.AlertEventRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final AlertEventRepository alertEventRepository;
    private final RestTemplate restTemplate;

    @Value("${alerting.webhook-url:}")
    private String webhookUrl;

    public NotificationService(AlertEventRepository alertEventRepository,
                               RestTemplate restTemplate) {
        this.alertEventRepository = alertEventRepository;
        this.restTemplate = restTemplate;
    }

    public void fireAlert(TelemetryMessage msg, AlertRule rule, String severity) {
        String ruleName = msg.getValue() < rule.getMin()
                ? msg.getSensor() + " < " + rule.getMin()
                : msg.getSensor() + " > " + rule.getMax();

        AlertEvent event = new AlertEvent();
        event.setMsgId(msg.getMsgId());
        event.setDeviceId(msg.getDeviceId());
        event.setSensor(msg.getSensor());
        event.setValue(msg.getValue());
        event.setRuleName(ruleName);
        event.setSeverity(severity);
        event.setCreatedAt(LocalDateTime.now());
        alertEventRepository.save(event);

        log.warn("[ALERT][{}] device={} sensor={} value={} rule={}",
                severity, msg.getDeviceId(), msg.getSensor(), msg.getValue(), ruleName);

        if (webhookUrl != null && !webhookUrl.isBlank()) {
            try {
                Map<String, Object> body = new LinkedHashMap<>();
                body.put("msg_id",       msg.getMsgId());
                body.put("device_id",    msg.getDeviceId());
                body.put("sensor",       msg.getSensor());
                body.put("value",        msg.getValue());
                body.put("rule",         ruleName);
                body.put("severity",     severity);
                body.put("triggered_at", Instant.now().toString());

                restTemplate.postForEntity(webhookUrl, body, String.class);
                log.info("[Webhook] Alert posted to {}", webhookUrl);
            } catch (Exception e) {
                log.error("[Webhook] Failed to POST alert: {}", e.getMessage());
            }
        }
    }
}
