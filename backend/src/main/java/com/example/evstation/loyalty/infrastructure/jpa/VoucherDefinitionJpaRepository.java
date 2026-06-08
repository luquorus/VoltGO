package com.example.evstation.loyalty.infrastructure.jpa;

import com.example.evstation.loyalty.domain.VoucherStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VoucherDefinitionJpaRepository extends JpaRepository<VoucherDefinitionEntity, UUID> {
    Optional<VoucherDefinitionEntity> findByCode(String code);
    List<VoucherDefinitionEntity> findByStatus(VoucherStatus status);

    @Query("SELECT v FROM VoucherDefinitionEntity v WHERE v.status = :status AND (v.startDate IS NULL OR v.startDate <= :now) AND (v.endDate IS NULL OR v.endDate >= :now)")
    List<VoucherDefinitionEntity> findAvailableActive(@Param("status") VoucherStatus status, @Param("now") Instant now);
}
