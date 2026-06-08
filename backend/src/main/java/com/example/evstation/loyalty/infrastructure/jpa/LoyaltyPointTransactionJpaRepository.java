package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.evstation.loyalty.domain.PointType;
import com.example.evstation.loyalty.domain.PointSource;

import java.util.UUID;

@Repository
public interface LoyaltyPointTransactionJpaRepository extends JpaRepository<LoyaltyPointTransactionEntity, UUID> {

    Page<LoyaltyPointTransactionEntity> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    @Query("SELECT COALESCE(SUM(p.points), 0) FROM LoyaltyPointTransactionEntity p WHERE p.userId = :userId AND p.type = :type")
    Integer sumEarnedPointsByUserId(@Param("userId") UUID userId, @Param("type") PointType type);

    long countBySourceAndSourceId(PointSource source, UUID sourceId);
}
