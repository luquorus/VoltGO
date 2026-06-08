package com.example.evstation.loyalty.infrastructure.jpa;

import com.example.evstation.loyalty.domain.RedemptionStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface VoucherRedemptionJpaRepository extends JpaRepository<VoucherRedemptionEntity, UUID> {
    Page<VoucherRedemptionEntity> findByUserIdOrderByRedeemedAtDesc(UUID userId, Pageable pageable);

    Page<VoucherRedemptionEntity> findByUserIdAndStatusOrderByRedeemedAtDesc(UUID userId, RedemptionStatus status, Pageable pageable);

    @Modifying
    @Query("UPDATE VoucherRedemptionEntity v SET v.status = :newStatus WHERE v.status = :oldStatus AND v.expiresAt < :now")
    int expireRedemptions(@Param("oldStatus") RedemptionStatus oldStatus, @Param("newStatus") RedemptionStatus newStatus, @Param("now") Instant now);

    long countByVoucherDefinitionId(UUID definitionId);

    boolean existsByUserIdAndVoucherDefinitionIdAndStatusIn(UUID userId, UUID definitionId, List<RedemptionStatus> statuses);

    @Query("SELECT COUNT(v) FROM VoucherRedemptionEntity v WHERE v.voucherDefinitionId = :definitionId")
    long countTotalRedemptions(@Param("definitionId") UUID definitionId);

    Page<VoucherRedemptionEntity> findByStatusOrderByRedeemedAtDesc(RedemptionStatus status, Pageable pageable);

    boolean existsByVoucherCode(String voucherCode);
}
