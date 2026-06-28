package com.example.evstation.common.config;

/**
 * Cache name constants used across all {@code @Cacheable}, {@code @CacheEvict},
 * and {@code @CachePut} annotations throughout the application.
 *
 * <p>Each constant corresponds to a named cache region configured in
 * {@link RedisCacheConfig} with its own TTL.
 */
public final class CacheNames {

    private CacheNames() {}

    // ── Station ──────────────────────────────────────────────────────────────

    /** Single station detail — key: station UUID */
    public static final String STATION_DETAIL = "station:detail";
    /** Station search by name — key: nameQuery + page + size */
    public static final String STATION_SEARCH = "station:search";
    /** Station radius query — key: lat + lng + radius + filters + page + size */
    public static final String STATION_RADIUS = "station:radius";

    // ── Trust ────────────────────────────────────────────────────────────────

    /** Trust score (integer) — key: station UUID */
    public static final String TRUST_SCORE = "trust:score";
    /** Trust breakdown map — key: station UUID */
    public static final String TRUST_BREAKDOWN = "trust:breakdown";
    /** Trust entity — key: station UUID */
    public static final String TRUST_ENTITY = "trust:entity";
    /** Global trust summary — key: always "global" */
    public static final String TRUST_SUMMARY = "trust:summary";

    // ── Ratings ──────────────────────────────────────────────────────────────

    /** Rating summary (avg, counts) — key: station UUID */
    public static final String RATING_SUMMARY = "rating:summary";
    /** Paginated rating list — key: stationId + page + size */
    public static final String RATING_PAGE = "rating:page";
    /** Single rating by ID — key: rating UUID */
    public static final String RATING_ID = "rating:id";

    // ── Loyalty ──────────────────────────────────────────────────────────────

    /** User loyalty profile — key: user UUID */
    public static final String LOYALTY_PROFILE = "loyalty:profile";
    /** User point history — key: userId + page + size */
    public static final String LOYALTY_HISTORY = "loyalty:history";

    // ── Vouchers ────────────────────────────────────────────────────────────

    /** All voucher definitions (admin) — key: "all" */
    public static final String VOUCHER_DEFINITIONS_ALL = "voucher:definitions:all";
    /** Single voucher definition — key: definition UUID */
    public static final String VOUCHER_DEFINITION_ID = "voucher:definition";
    /** Available vouchers for user — key: user UUID */
    public static final String VOUCHER_AVAILABLE = "voucher:available";
    /** User redemptions list — key: userId + status + page + size */
    public static final String VOUCHER_REDEMPTIONS = "voucher:redemptions";
    /** Single redemption detail — key: redemption UUID */
    public static final String VOUCHER_REDEMPTION_ID = "voucher:redemption";

    // ── Badges ───────────────────────────────────────────────────────────────

    /** User earned badges — key: user UUID */
    public static final String BADGE_USER = "badge:user";
    /** All badges with progress — key: user UUID */
    public static final String BADGE_PROGRESS = "badge:progress";

    // ── Booking ─────────────────────────────────────────────────────────────

    /** User booking list — key: userId + page + size */
    public static final String BOOKING_USER = "booking:user";
    /** Single booking — key: booking UUID */
    public static final String BOOKING_ID = "booking:id";

    // ── Battery Swap ────────────────────────────────────────────────────────

    /** Nearby swap stations — key: lat + lng + radiusKm */
    public static final String BSWAP_NEARBY = "bswap:nearby";
    /** Swap station detail — key: station UUID */
    public static final String BSWAP_DETAIL = "bswap:detail";
    /** All swap stations — key: "all" */
    public static final String BSWAP_ALL = "bswap:all";
    /** Pile/slot state (frequently updated) — key: station UUID */
    public static final String BSWAP_PILES = "bswap:piles";
    /** User swap reservations — key: user UUID */
    public static final String BSWAP_USER_RESERVATIONS = "bswap:user";
    /** Single swap reservation — key: reservation UUID */
    public static final String BSWAP_RESERVATION_ID = "bswap:reservation";
    /** Swap trust score — key: station UUID */
    public static final String BSWAP_TRUST_SCORE = "bswap:trust:score";
    /** Swap trust DTO — key: station UUID */
    public static final String BSWAP_TRUST_DTO = "bswap:trust:dto";
    /** Swap trust entity — key: station UUID */
    public static final String BSWAP_TRUST_ENTITY = "bswap:trust:entity";
    /** Swap trust breakdown — key: station UUID */
    public static final String BSWAP_TRUST_BREAKDOWN = "bswap:trust:breakdown";
    /** Swap trust level — key: station UUID */
    public static final String BSWAP_TRUST_LEVEL = "bswap:trust:level";

    // ── Recommendations ─────────────────────────────────────────────────────

    /** Route recommendations — key: canonical hash of request parameters */
    public static final String RECOMMEND = "recommend";

    // ── Collaborator ────────────────────────────────────────────────────────

    /** All collaborators (admin) — key: page + size */
    public static final String COLLABORATOR_ALL = "collaborator:all";
    /** Single collaborator — key: collaborator UUID */
    public static final String COLLABORATOR_ID = "collaborator:id";
    /** Collaborator by account ID — key: user account UUID */
    public static final String COLLABORATOR_ACCOUNT = "collaborator:account";
}
