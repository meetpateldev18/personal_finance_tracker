package com.financetracker.budgetservice.repository;

import com.financetracker.budgetservice.model.Budget;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface BudgetRepository extends JpaRepository<Budget, UUID> {

    List<Budget> findByUserIdAndIsActiveTrue(UUID userId);

    @Query("SELECT b FROM Budget b WHERE b.userId = :userId AND b.isActive = true " +
           "AND b.startDate <= :today AND b.endDate >= :today " +
           "AND (b.categoryId = :categoryId OR b.categoryId IS NULL)")
    List<Budget> findActiveBudgetsForUserAndCategory(
            @Param("userId") UUID userId,
            @Param("categoryId") UUID categoryId,
            @Param("today") LocalDate today);

    @Query("SELECT b FROM Budget b WHERE b.isActive = true AND b.endDate < :today")
    List<Budget> findExpiredBudgets(@Param("today") LocalDate today);
}
