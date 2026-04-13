package com.iot.ingestion.repository;

import com.iot.ingestion.entity.TelemetryReading;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TelemetryRepository extends JpaRepository<TelemetryReading, String> {
}
