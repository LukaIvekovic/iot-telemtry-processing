package com.iot.alerting.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
public class DeduplicationService {

    private static final String KEY_PREFIX = "dedup:alerting:";

    private final StringRedisTemplate redisTemplate;

    @Value("${deduplication.ttl-seconds}")
    private long ttlSeconds;

    public DeduplicationService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public boolean isDuplicate(String msgId) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(KEY_PREFIX + msgId));
    }

    public void markProcessed(String msgId) {
        redisTemplate.opsForValue().set(KEY_PREFIX + msgId, "1", ttlSeconds, TimeUnit.SECONDS);
    }
}
