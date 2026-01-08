package com.example.evstation.collaborator.infrastructure.jpa;

import com.example.evstation.collaborator.domain.ContractStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface ContractJpaRepository extends JpaRepository<ContractEntity, UUID> {
    
    List<ContractEntity> findByCollaboratorIdOrderByCreatedAtDesc(UUID collaboratorId);
    
    Page<ContractEntity> findByCollaboratorIdOrderByCreatedAtDesc(UUID collaboratorId, Pageable pageable);
    
    /**
     * Find active contracts for a collaborator that are effective on a given date.
     * Effective means: status=ACTIVE and date is between start_date and end_date
     */
    @Query("""
        SELECT c FROM ContractEntity c 
        WHERE c.collaboratorId = :collaboratorId 
        AND c.status = 'ACTIVE'
        AND c.startDate <= :date 
        AND c.endDate >= :date
        ORDER BY c.createdAt DESC
        """)
    List<ContractEntity> findEffectiveActiveContracts(
            @Param("collaboratorId") UUID collaboratorId,
            @Param("date") LocalDate date);
    
    /**
     * Check if collaborator has any effective active contract on a given date.
     */
    @Query("""
        SELECT COUNT(c) > 0 FROM ContractEntity c 
        WHERE c.collaboratorId = :collaboratorId 
        AND c.status = 'ACTIVE'
        AND c.startDate <= :date 
        AND c.endDate >= :date
        """)
    boolean hasEffectiveActiveContract(
            @Param("collaboratorId") UUID collaboratorId,
            @Param("date") LocalDate date);
    
    List<ContractEntity> findByStatusOrderByCreatedAtDesc(ContractStatus status);
}

