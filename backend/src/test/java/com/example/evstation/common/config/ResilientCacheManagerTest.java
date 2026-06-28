package com.example.evstation.common.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.cache.Cache;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ResilientCacheManagerTest {

    @Mock
    private RedisCacheManager delegate;

    @Mock
    private RedisTemplate<String, Object> redisTemplate;

    @Mock
    private RedisConnectionFactory connectionFactory;

    @Mock
    private RedisConnection redisConnection;

    @Test
    void getCache_whenRedisUnavailable_returnsNoOpCache() {
        when(redisTemplate.getConnectionFactory()).thenReturn(connectionFactory);
        when(connectionFactory.getConnection()).thenThrow(new RuntimeException("Connection refused"));

        ResilientCacheManager manager = new ResilientCacheManager(delegate, redisTemplate);

        Cache cache = manager.getCache("any-cache-name");

        assertThat(cache).isNotNull();
        assertThat(cache.getName()).isEqualTo("no-op");
        assertThat(cache.get("any-key")).isNull();
        verify(delegate, never()).getCache(any());
    }

    @Test
    void getCache_whenRedisAvailable_delegatesToRedisCacheManager() {
        when(redisTemplate.getConnectionFactory()).thenReturn(connectionFactory);
        when(connectionFactory.getConnection()).thenReturn(redisConnection);
        when(redisConnection.ping()).thenReturn("PONG");

        Cache redisCache = mock(Cache.class);
        when(delegate.getCache("station:detail")).thenReturn(redisCache);

        ResilientCacheManager manager = new ResilientCacheManager(delegate, redisTemplate);

        Cache cache = manager.getCache("station:detail");

        assertThat(cache).isEqualTo(redisCache);
    }

    @Test
    void getCache_whenDelegateReturnsNull_returnsNoOpCache() {
        when(redisTemplate.getConnectionFactory()).thenReturn(connectionFactory);
        when(connectionFactory.getConnection()).thenReturn(redisConnection);
        when(redisConnection.ping()).thenReturn("PONG");
        when(delegate.getCache("unknown-cache")).thenReturn(null);

        ResilientCacheManager manager = new ResilientCacheManager(delegate, redisTemplate);

        Cache cache = manager.getCache("unknown-cache");

        assertThat(cache).isNotNull();
        assertThat(cache.getName()).isEqualTo("no-op");
    }

    @Test
    void noOpCache_neverStoresAnything() {
        ResilientCacheManager.NoOpCache cache = ResilientCacheManager.NoOpCache.INSTANCE;

        cache.put("key", "value");
        assertThat(cache.get("key")).isNull();
        assertThat(cache.get("key", String.class)).isNull();

        cache.evict("key");
        cache.clear();

        assertThat(cache.putIfAbsent("key", "value")).isNull();
    }

    @Test
    void resilientCache_wrapsGetWithTryCatch() {
        Cache delegateCache = mock(Cache.class);
        when(delegateCache.get("key")).thenThrow(new RuntimeException("Redis is down"));

        ResilientCacheManager.ResilientCache cache =
                new ResilientCacheManager.ResilientCache(delegateCache, "test");

        Cache.ValueWrapper result = cache.get("key");

        assertThat(result).isNull();
    }

    @Test
    void resilientCache_wrapsPutWithTryCatch() {
        Cache delegateCache = mock(Cache.class);
        doThrow(new RuntimeException("Redis is down")).when(delegateCache).put("key", "value");

        ResilientCacheManager.ResilientCache cache =
                new ResilientCacheManager.ResilientCache(delegateCache, "test");

        cache.put("key", "value");
    }

    @Test
    void resilientCache_wrapsEvictWithTryCatch() {
        Cache delegateCache = mock(Cache.class);
        doThrow(new RuntimeException("Redis is down")).when(delegateCache).evict("key");

        ResilientCacheManager.ResilientCache cache =
                new ResilientCacheManager.ResilientCache(delegateCache, "test");

        cache.evict("key");
    }

    @Test
    void resilientCache_wrapsClearWithTryCatch() {
        Cache delegateCache = mock(Cache.class);
        doThrow(new RuntimeException("Redis is down")).when(delegateCache).clear();

        ResilientCacheManager.ResilientCache cache =
                new ResilientCacheManager.ResilientCache(delegateCache, "test");

        cache.clear();
    }

    @Test
    void resilientCache_delegatesSuccessfully_whenNoException() {
        Cache.ValueWrapper wrapper = mock(Cache.ValueWrapper.class);
        Cache delegateCache = mock(Cache.class);
        when(delegateCache.get("key")).thenReturn(wrapper);

        ResilientCacheManager.ResilientCache cache =
                new ResilientCacheManager.ResilientCache(delegateCache, "test");

        Cache.ValueWrapper result = cache.get("key");

        assertThat(result).isEqualTo(wrapper);
    }
}
