package com.iot.ingestion.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
public class DeduplicationService {

    private static final String KEY_PREFIX = "dedup:ingestion:";

    private final StringRedisTemplate redisTemplate;
    private final long ttlSeconds;

    public DeduplicationService(StringRedisTemplate redisTemplate,
                                @Value("${deduplication.ttl-seconds}") long ttlSeconds) {
        this.redisTemplate = redisTemplate;
        this.ttlSeconds = ttlSeconds;
    }

    public boolean isDuplicate(String msgId) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(KEY_PREFIX + msgId));
    }

    public void markProcessed(String msgId) {
        redisTemplate.opsForValue().set(KEY_PREFIX + msgId, "1", Duration.ofSeconds(ttlSeconds));
    }
}
