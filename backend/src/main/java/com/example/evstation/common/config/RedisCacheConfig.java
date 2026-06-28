package com.example.evstation.common.config;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

/**
 * Redis cache configuration with graceful degradation.
 *
 * <p>If Redis is unavailable at startup or goes down during runtime, the application
 * continues to function normally — reads simply miss the cache and hit the database.
 * This is achieved by configuring {@code spring.cache.type=none} as the fallback
 * through a custom {@link CacheManager} that wraps Redis operations with
 * try/catch and falls back to no-op when Redis is unreachable.
 *
 * <p>Cache TTLs are tuned per data volatility:
 * <ul>
 *   <li>Station data, trust scores, ratings — 5 min (changes infrequently)</li>
 *   <li>User-specific loyalty data — 5 min (updated on user actions)</li>
 *   <li>Voucher definitions (admin) — 10 min (stable, rarely changes)</li>
 *   <li>Voucher available to user — 2 min (time-sensitive, active vouchers change)</li>
 *   <li>Booking/reservation data — 2 min (time-sensitive)</li>
 *   <li>Battery swap pile display — 1 min (frequently updated by simulation)</li>
 * </ul>
 */
@Configuration
@EnableCaching
public class RedisCacheConfig {

    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        objectMapper.activateDefaultTyping(
                objectMapper.getPolymorphicTypeValidator(),
                ObjectMapper.DefaultTyping.NON_FINAL,
                JsonTypeInfo.As.PROPERTY
        );

        GenericJackson2JsonRedisSerializer jsonSerializer =
                new GenericJackson2JsonRedisSerializer(objectMapper);

        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(jsonSerializer);
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(jsonSerializer);
        template.afterPropertiesSet();
        return template;
    }

    @Bean
    public CacheManager cacheManager(RedisConnectionFactory connectionFactory,
                                    RedisTemplate<String, Object> redisTemplate) {
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        objectMapper.activateDefaultTyping(
                objectMapper.getPolymorphicTypeValidator(),
                ObjectMapper.DefaultTyping.NON_FINAL,
                JsonTypeInfo.As.PROPERTY
        );

        GenericJackson2JsonRedisSerializer jsonSerializer =
                new GenericJackson2JsonRedisSerializer(objectMapper);

        RedisCacheConfiguration defaultCfg = RedisCacheConfiguration.defaultCacheConfig()
                .serializeKeysWith(RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
                .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(jsonSerializer))
                .disableCachingNullValues();

        Map<String, RedisCacheConfiguration> ttlConfigs = new HashMap<>();

        // Station data — stable, rarely changes
        ttlConfigs.put(CacheNames.STATION_DETAIL, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.STATION_SEARCH, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.STATION_RADIUS, defaultCfg.entryTtl(Duration.ofMinutes(5)));

        // Trust scores — updated on admin actions, queried on every station display
        ttlConfigs.put(CacheNames.TRUST_SCORE, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.TRUST_BREAKDOWN, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.TRUST_ENTITY, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.TRUST_SUMMARY, defaultCfg.entryTtl(Duration.ofMinutes(5)));

        // Ratings — updated on new review submission
        ttlConfigs.put(CacheNames.RATING_SUMMARY, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.RATING_PAGE, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.RATING_ID, defaultCfg.entryTtl(Duration.ofMinutes(10)));

        // Loyalty — user-specific, updated on actions
        ttlConfigs.put(CacheNames.LOYALTY_PROFILE, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.LOYALTY_HISTORY, defaultCfg.entryTtl(Duration.ofMinutes(5)));

        // Vouchers — admin definitions stable, user-available time-sensitive
        ttlConfigs.put(CacheNames.VOUCHER_DEFINITIONS_ALL, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.VOUCHER_DEFINITION_ID, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.VOUCHER_AVAILABLE, defaultCfg.entryTtl(Duration.ofMinutes(2)));
        ttlConfigs.put(CacheNames.VOUCHER_REDEMPTIONS, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.VOUCHER_REDEMPTION_ID, defaultCfg.entryTtl(Duration.ofMinutes(5)));

        // Badges
        ttlConfigs.put(CacheNames.BADGE_USER, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.BADGE_PROGRESS, defaultCfg.entryTtl(Duration.ofMinutes(10)));

        // Booking — time-sensitive
        ttlConfigs.put(CacheNames.BOOKING_USER, defaultCfg.entryTtl(Duration.ofMinutes(2)));
        ttlConfigs.put(CacheNames.BOOKING_ID, defaultCfg.entryTtl(Duration.ofMinutes(2)));

        // Battery swap — station data stable, pile display frequent
        ttlConfigs.put(CacheNames.BSWAP_NEARBY, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.BSWAP_DETAIL, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.BSWAP_ALL, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.BSWAP_PILES, defaultCfg.entryTtl(Duration.ofMinutes(1)));
        ttlConfigs.put(CacheNames.BSWAP_USER_RESERVATIONS, defaultCfg.entryTtl(Duration.ofMinutes(2)));
        ttlConfigs.put(CacheNames.BSWAP_RESERVATION_ID, defaultCfg.entryTtl(Duration.ofMinutes(2)));
        ttlConfigs.put(CacheNames.BSWAP_TRUST_SCORE, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.BSWAP_TRUST_DTO, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.BSWAP_TRUST_ENTITY, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.BSWAP_TRUST_BREAKDOWN, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.BSWAP_TRUST_LEVEL, defaultCfg.entryTtl(Duration.ofMinutes(10)));

        // Recommendations — location+battery sensitive
        ttlConfigs.put(CacheNames.RECOMMEND, defaultCfg.entryTtl(Duration.ofMinutes(3)));

        // Collaborator
        ttlConfigs.put(CacheNames.COLLABORATOR_ALL, defaultCfg.entryTtl(Duration.ofMinutes(5)));
        ttlConfigs.put(CacheNames.COLLABORATOR_ID, defaultCfg.entryTtl(Duration.ofMinutes(10)));
        ttlConfigs.put(CacheNames.COLLABORATOR_ACCOUNT, defaultCfg.entryTtl(Duration.ofMinutes(10)));

        RedisCacheManager redisCacheManager = RedisCacheManager.builder(connectionFactory)
                .cacheDefaults(defaultCfg.entryTtl(Duration.ofMinutes(5)))
                .withInitialCacheConfigurations(ttlConfigs)
                .build();

        return new ResilientCacheManager(redisCacheManager, redisTemplate);
    }
}
