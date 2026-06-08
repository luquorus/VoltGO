package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.evstation.loyalty.domain.BadgeCriteriaType;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LoyaltyBadgeJpaRepository extends JpaRepository<LoyaltyBadgeEntity, UUID> {

    Optional<LoyaltyBadgeEntity> findByCode(String code);

    @Query("SELECT b FROM LoyaltyBadgeEntity b WHERE b.criteriaType = :criteriaType AND b.criteriaValue <= :currentValue ORDER BY b.criteriaValue DESC")
    List<LoyaltyBadgeEntity> findByCriteriaTypeAndCriteriaValueLessThanOrEqual(
            @Param("criteriaType") BadgeCriteriaType criteriaType,
            @Param("currentValue") Integer currentValue);
}
