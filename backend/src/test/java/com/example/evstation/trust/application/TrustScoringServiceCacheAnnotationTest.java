package com.example.evstation.trust.application;

import com.example.evstation.common.config.CacheNames;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Verifies TrustScoringService cache annotations via reflection.
 */
class TrustScoringServiceCacheAnnotationTest {

    @Test
    void recalculate_hasCachingEvict_forAllTrustCaches() throws Exception {
        Method method = TrustScoringService.class.getMethod("recalculate", java.util.UUID.class);

        org.springframework.cache.annotation.Caching caching = method.getAnnotation(
                org.springframework.cache.annotation.Caching.class);
        assertThat(caching).isNotNull();

        org.springframework.cache.annotation.CacheEvict[] evicts = caching.evict();
        assertThat(evicts).hasSize(4);

        java.util.Set<String> evictNames = new java.util.HashSet<>();
        for (org.springframework.cache.annotation.CacheEvict evict : evicts) {
            assertThat(evict.value()).hasSize(1);
            evictNames.add(evict.value()[0]);
        }

        assertThat(evictNames).contains(
                CacheNames.TRUST_SCORE,
                CacheNames.TRUST_BREAKDOWN,
                CacheNames.TRUST_ENTITY,
                CacheNames.TRUST_SUMMARY
        );

        // TRUST_SUMMARY should evict all entries (allEntries=true), others use stationId key
        boolean summaryAllEntries = false;
        boolean othersUseKey = true;
        for (org.springframework.cache.annotation.CacheEvict evict : evicts) {
            String name = evict.value()[0];
            if (name.equals(CacheNames.TRUST_SUMMARY)) {
                summaryAllEntries = evict.allEntries();
            } else {
                if (!evict.key().equals("#stationId")) {
                    othersUseKey = false;
                }
            }
        }
        assertThat(summaryAllEntries).isTrue();
        assertThat(othersUseKey).isTrue();
    }

    @Test
    void getTrustScore_hasCacheable() throws Exception {
        Method method = TrustScoringService.class.getMethod("getTrustScore", java.util.UUID.class);
        org.springframework.cache.annotation.Cacheable cacheable = method.getAnnotation(
                org.springframework.cache.annotation.Cacheable.class);

        assertThat(cacheable).isNotNull();
        assertThat(cacheable.value()).containsExactly(CacheNames.TRUST_SCORE);
        assertThat(cacheable.key()).isEqualTo("#stationId");
    }

    @Test
    void getTrustBreakdown_hasCacheable() throws Exception {
        Method method = TrustScoringService.class.getMethod("getTrustBreakdown", java.util.UUID.class);
        org.springframework.cache.annotation.Cacheable cacheable = method.getAnnotation(
                org.springframework.cache.annotation.Cacheable.class);

        assertThat(cacheable).isNotNull();
        assertThat(cacheable.value()).containsExactly(CacheNames.TRUST_BREAKDOWN);
        assertThat(cacheable.key()).isEqualTo("#stationId");
    }

    @Test
    void getTrustEntity_hasCacheable() throws Exception {
        Method method = TrustScoringService.class.getMethod("getTrustEntity", java.util.UUID.class);
        org.springframework.cache.annotation.Cacheable cacheable = method.getAnnotation(
                org.springframework.cache.annotation.Cacheable.class);

        assertThat(cacheable).isNotNull();
        assertThat(cacheable.value()).containsExactly(CacheNames.TRUST_ENTITY);
        assertThat(cacheable.key()).isEqualTo("#stationId");
    }

    @Test
    void getSummary_hasCacheable_withGlobalKey() throws Exception {
        Method method = TrustScoringService.class.getMethod("getSummary");
        org.springframework.cache.annotation.Cacheable cacheable = method.getAnnotation(
                org.springframework.cache.annotation.Cacheable.class);

        assertThat(cacheable).isNotNull();
        assertThat(cacheable.value()).containsExactly(CacheNames.TRUST_SUMMARY);
        assertThat(cacheable.key()).isEqualTo("'global'");
    }
}
