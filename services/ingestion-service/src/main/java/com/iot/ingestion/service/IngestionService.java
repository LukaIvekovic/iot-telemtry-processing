package com.iot.ingestion.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iot.ingestion.dto.TelemetryMessage;
import com.iot.ingestion.entity.TelemetryReading;
import com.iot.ingestion.repository.TelemetryRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;

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

    public boolean processMessage(String topic, String payload) {
        TelemetryMessage message;
        try {
            message = objectMapper.readValue(payload, TelemetryMessage.class);
        } catch (Exception e) {
            log.error("[Ingestion] Discarding unparseable message from topic={}: {}", topic, e.getMessage());
            return true;
        }

        try {
            if (deduplicationService.isDuplicate(message.getMsgId())) {
                log.info("[Dedup] Duplicate msg_id={}, discarding", message.getMsgId());
                return true;
            }

            TelemetryReading reading = new TelemetryReading();
            reading.setMsgId(message.getMsgId());
            reading.setDeviceId(message.getDeviceId());
            reading.setSensor(message.getSensor());
            reading.setValue(message.getValue());
            reading.setUnit(message.getUnit());
            reading.setTimestamp(message.getTimestamp());
            reading.setReceivedAt(Instant.now());

            telemetryRepository.save(reading);
            deduplicationService.markProcessed(message.getMsgId());

            log.info("[Ingestion] Stored msg_id={} device={} sensor={} value={}",
                    message.getMsgId(), message.getDeviceId(), message.getSensor(), message.getValue());
            return true;

        } catch (Exception e) {
            log.error("[Ingestion] Transient failure for msg_id={}, leaving unacknowledged for redelivery: {}",
                    message.getMsgId(), e.getMessage());
            return false;
        }
    }
}
