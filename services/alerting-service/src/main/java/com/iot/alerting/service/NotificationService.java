package com.iot.alerting.service;

import com.iot.alerting.config.AlertRulesConfig.AlertRule;
import com.iot.alerting.dto.TelemetryMessage;
import com.iot.alerting.entity.AlertEvent;
import com.iot.alerting.repository.AlertEventRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final AlertEventRepository alertEventRepository;

    public NotificationService(AlertEventRepository alertEventRepository) {
        this.alertEventRepository = alertEventRepository;
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

        log.warn("[ALERT][{}] device={} sensor={} value={} (rule: {}-{})",
                severity, msg.getDeviceId(), msg.getSensor(), msg.getValue(),
                rule.getMin(), rule.getMax());
    }
}
