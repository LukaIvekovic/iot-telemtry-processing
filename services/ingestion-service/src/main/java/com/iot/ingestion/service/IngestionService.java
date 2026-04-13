package com.iot.ingestion.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iot.ingestion.dto.TelemetryMessage;
import com.iot.ingestion.entity.TelemetryReading;
import com.iot.ingestion.repository.TelemetryRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
public class IngestionService {

    private static final Logger log = LoggerFactory.getLogger(IngestionService.class);

    private final DeduplicationService deduplicationService;
    private final TelemetryRepository telemetryRepository;
    private final ObjectMapper objectMapper;

    public IngestionService(DeduplicationService deduplicationService,
                            TelemetryRepository telemetryRepository,
                            ObjectMapper objectMapper) {
        this.deduplicationService = deduplicationService;
        this.telemetryRepository = telemetryRepository;
        this.objectMapper = objectMapper;
    }

    public void processMessage(String topic, String payload) {
        try {
            TelemetryMessage message = objectMapper.readValue(payload, TelemetryMessage.class);

            if (deduplicationService.isDuplicate(message.getMsgId())) {
                log.info("[Dedup] Duplicate msg_id={}, discarding", message.getMsgId());
                return;
            }

            TelemetryReading reading = new TelemetryReading();
            reading.setMsgId(message.getMsgId());
            reading.setDeviceId(message.getDeviceId());
            reading.setSensor(message.getSensor());
            reading.setValue(message.getValue());
            reading.setUnit(message.getUnit());
            reading.setTimestamp(message.getTimestamp());
            reading.setReceivedAt(LocalDateTime.now());

            telemetryRepository.save(reading);
            deduplicationService.markProcessed(message.getMsgId());

            log.info("[Ingestion] Stored msg_id={} device={} sensor={} value={}",
                    message.getMsgId(), message.getDeviceId(), message.getSensor(), message.getValue());

        } catch (Exception e) {
            log.error("[Ingestion] Failed to process message from topic={}: {}", topic, e.getMessage(), e);
        }
    }
}
