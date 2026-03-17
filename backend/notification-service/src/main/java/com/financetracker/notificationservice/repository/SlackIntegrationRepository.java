package com.financetracker.notificationservice.repository;

import com.financetracker.notificationservice.model.SlackIntegration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface SlackIntegrationRepository extends JpaRepository<SlackIntegration, UUID> {
    Optional<SlackIntegration> findByUserIdAndIsActiveTrue(UUID userId);
}
