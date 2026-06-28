package com.example.evstation.common.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.core.RedisTemplate;

import java.util.Collection;
import java.util.Collections;
import java.util.concurrent.ConcurrentHashMap;

/**
 * A resilient {@link CacheManager} that wraps a real Redis {@link CacheManager}
 * with try/catch guards around every operation.
 *
 * <p>If Redis becomes unavailable at any point (startup failure, network partition,
 * server restart), every cache read silently misses and every cache write is a no-op.
 * The application continues to function normally against the database.
 *
 * <p>If Redis recovers, the cache automatically resumes — no restart needed.
 */
@Slf4j
public class ResilientCacheManager implements CacheManager {

    private final CacheManager delegate;
    private final RedisTemplate<String, Object> redisTemplate;
    private final boolean redisAvailable;

    private final Collection<String> cacheNames = Collections.newSetFromMap(new ConcurrentHashMap<>());

    public ResilientCacheManager(RedisCacheManager delegate, RedisTemplate<String, Object> redisTemplate) {
        this.delegate = delegate;
        this.redisTemplate = redisTemplate;
        this.redisAvailable = checkRedisAvailable();
    }

    private boolean checkRedisAvailable() {
        try {
            redisTemplate.getConnectionFactory().getConnection().ping();
            log.info("Redis cache: connection established");
            return true;
        } catch (Exception e) {
            log.warn("Redis cache: not available at startup ({}). "
                    + "Cache is disabled — application will run against the database. "
                    + "Cache will resume automatically when Redis recovers.", e.getMessage());
            return false;
        }
    }

    @Override
    public Cache getCache(String name) {
        if (!redisAvailable) {
            return NoOpCache.INSTANCE;
        }
        try {
            Cache cache = delegate.getCache(name);
            if (cache == null) {
                return NoOpCache.INSTANCE;
            }
            return new ResilientCache(cache, name);
        } catch (RedisConnectionFailureException e) {
            log.warn("Redis connection lost for cache '{}'. Falling back to no-op. "
                    + "Cache will resume when connection recovers.", name);
            return NoOpCache.INSTANCE;
        } catch (Exception e) {
            log.warn("Cache '{}' unavailable ({}). Falling back to no-op.", name, e.getMessage());
            return NoOpCache.INSTANCE;
        }
    }

    @Override
    public Collection<String> getCacheNames() {
        try {
            return delegate.getCacheNames();
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    /**
     * A no-operation cache that never stores or retrieves anything.
     * Used when Redis is unavailable — every get() returns null (cache miss),
     * every put() is silently discarded.
     */
    private static final class NoOpCache implements Cache {

        static final NoOpCache INSTANCE = new NoOpCache();

        @Override
        public String getName() {
            return "no-op";
        }

        @Override
        public Object getNativeCache() {
            return null;
        }

        @Override
        public ValueWrapper get(Object key) {
            return null;
        }

        @Override
        @SuppressWarnings("unchecked")
        public <T> T get(Object key, Class<T> type) {
            return null;
        }

        @Override
        @SuppressWarnings("unchecked")
        public <T> T get(Object key, java.util.concurrent.Callable<T> valueLoader) {
            return null;
        }

        @Override
        public void put(Object key, Object value) {
            // no-op
        }

        @Override
        public void evict(Object key) {
            // no-op
        }

        @Override
        public void clear() {
            // no-op
        }

        @Override
        public ValueWrapper putIfAbsent(Object key, Object value) {
            return null;
        }
    }

    /**
     * A cache wrapper that guards every real operation with try/catch.
     * If any operation fails, it silently falls back to no-op for that call.
     */
    private static final class ResilientCache implements Cache {

        private final Cache delegate;
        private final String name;

        ResilientCache(Cache delegate, String name) {
            this.delegate = delegate;
            this.name = name;
        }

        @Override
        public String getName() {
            return name;
        }

        @Override
        public Object getNativeCache() {
            try {
                return delegate.getNativeCache();
            } catch (Exception e) {
                log.warn("Cache '{}': getNativeCache failed", name);
                return null;
            }
        }

        @Override
        public ValueWrapper get(Object key) {
            try {
                return delegate.get(key);
            } catch (RedisConnectionFailureException e) {
                log.warn("Redis connection lost during get('{}'). Cache miss.", key);
                return null;
            } catch (Exception e) {
                log.warn("Cache '{}': get('{}') failed: {}", name, key, e.getMessage());
                return null;
            }
        }

        @Override
        @SuppressWarnings("unchecked")
        public <T> T get(Object key, Class<T> type) {
            try {
                return delegate.get(key, type);
            } catch (RedisConnectionFailureException e) {
                log.warn("Redis connection lost during get('{}'). Cache miss.", key);
                return null;
            } catch (Exception e) {
                log.warn("Cache '{}': get('{}', type) failed: {}", name, key, e.getMessage());
                return null;
            }
        }

        @Override
        @SuppressWarnings("unchecked")
        public <T> T get(Object key, java.util.concurrent.Callable<T> valueLoader) {
            try {
                return delegate.get(key, valueLoader);
            } catch (RedisConnectionFailureException e) {
                log.warn("Redis connection lost during get('{}', loader). Cache miss.", key);
                try {
                    return valueLoader.call();
                } catch (Exception ex) {
                    throw new RuntimeException(ex);
                }
            } catch (Exception e) {
                log.warn("Cache '{}': get('{}', loader) failed: {}", name, key, e.getMessage());
                try {
                    return valueLoader.call();
                } catch (Exception ex) {
                    throw new RuntimeException(ex);
                }
            }
        }

        @Override
        public void put(Object key, Object value) {
            try {
                delegate.put(key, value);
            } catch (RedisConnectionFailureException e) {
                log.warn("Redis connection lost during put('{}'). Write discarded.", key);
            } catch (Exception e) {
                log.warn("Cache '{}': put('{}') failed: {}", name, key, e.getMessage());
            }
        }

        @Override
        public void evict(Object key) {
            try {
                delegate.evict(key);
            } catch (RedisConnectionFailureException e) {
                log.warn("Redis connection lost during evict('{}'). Eviction skipped.", key);
            } catch (Exception e) {
                log.warn("Cache '{}': evict('{}') failed: {}", name, key, e.getMessage());
            }
        }

        @Override
        public void clear() {
            try {
                delegate.clear();
            } catch (RedisConnectionFailureException e) {
                log.warn("Redis connection lost during clear(). Cache may be stale.");
            } catch (Exception e) {
                log.warn("Cache '{}': clear() failed: {}", name, e.getMessage());
            }
        }

        @Override
        public ValueWrapper putIfAbsent(Object key, Object value) {
            try {
                return delegate.putIfAbsent(key, value);
            } catch (RedisConnectionFailureException e) {
                log.warn("Redis connection lost during putIfAbsent('{}'). Returning null (may cause duplicate writes).", key);
                return null;
            } catch (Exception e) {
                log.warn("Cache '{}': putIfAbsent('{}') failed: {}", name, key, e.getMessage());
                return null;
            }
        }
    }
}
