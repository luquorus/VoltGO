package com.example.evstation.station.application;

import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import com.example.evstation.common.config.CacheNames;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Verifies that StationQueryService methods carry the correct cache annotations.
 *
 * <p>Since this project uses pure unit tests (Mockito, no Spring context), we verify
 * cache correctness by inspecting annotation metadata rather than running full AOP.
 */
class StationQueryServiceCacheAnnotationTest {

    @Test
    void findStationDetail_hasCacheable_withCorrectCacheNameAndKey() throws Exception {
        Method method = StationQueryService.class.getMethod("findStationDetail", java.util.UUID.class);

        org.springframework.cache.annotation.Cacheable cacheable = method.getAnnotation(
                org.springframework.cache.annotation.Cacheable.class);

        assertThat(cacheable).isNotNull();
        assertThat(cacheable.value()).containsExactly(CacheNames.STATION_DETAIL);
        assertThat(cacheable.key()).isEqualTo("#stationId");
    }

    @Test
    void findStationsWithinRadius_hasCacheable_withCorrectCacheName() throws Exception {
        Method method = StationQueryService.class.getMethod(
                "findStationsWithinRadius",
                double.class, double.class, double.class,
                java.math.BigDecimal.class, Boolean.class,
                org.springframework.data.domain.Pageable.class
        );

        org.springframework.cache.annotation.Cacheable cacheable = method.getAnnotation(
                org.springframework.cache.annotation.Cacheable.class);

        assertThat(cacheable).isNotNull();
        assertThat(cacheable.value()).containsExactly(CacheNames.STATION_RADIUS);
        assertThat(cacheable.key()).isNotBlank();
        assertThat(cacheable.key()).contains("#lat");
        assertThat(cacheable.key()).contains("#lng");
        assertThat(cacheable.key()).contains("#radiusKm");
    }

    @Test
    void searchStationsByName_hasCacheable_withCorrectCacheNameAndKey() throws Exception {
        Method method = StationQueryService.class.getMethod(
                "searchStationsByName",
                String.class,
                org.springframework.data.domain.Pageable.class
        );

        org.springframework.cache.annotation.Cacheable cacheable = method.getAnnotation(
                org.springframework.cache.annotation.Cacheable.class);

        assertThat(cacheable).isNotNull();
        assertThat(cacheable.value()).containsExactly(CacheNames.STATION_SEARCH);
        assertThat(cacheable.key()).contains("#nameQuery");
        assertThat(cacheable.key()).contains("#pageable.pageNumber");
    }
}
