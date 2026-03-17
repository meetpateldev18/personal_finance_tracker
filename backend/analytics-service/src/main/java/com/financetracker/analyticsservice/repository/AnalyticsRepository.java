package com.financetracker.analyticsservice.repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.JpaRepository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Read-only queries against the shared transactions table.
 * Analytics service only reads — it never writes to transactions.
 */
@Repository
public interface AnalyticsRepository extends JpaRepository<com.financetracker.analyticsservice.model.TransactionView, UUID> {

    @Query(value = "SELECT SUM(t.amount) FROM transactions t " +
                   "WHERE t.user_id = :userId AND t.type = :type " +
                   "AND t.transaction_date BETWEEN :from AND :to",
           nativeQuery = true)
    BigDecimal sumByType(@Param("userId") UUID userId,
                          @Param("type") String type,
                          @Param("from") LocalDate from,
                          @Param("to") LocalDate to);

    @Query(value = "SELECT t.category_id, c.name, SUM(t.amount), COUNT(t.id) " +
                   "FROM transactions t " +
                   "LEFT JOIN categories c ON c.id = t.category_id " +
                   "WHERE t.user_id = :userId AND t.type = 'EXPENSE' " +
                   "AND t.transaction_date BETWEEN :from AND :to " +
                   "GROUP BY t.category_id, c.name " +
                   "ORDER BY SUM(t.amount) DESC",
           nativeQuery = true)
    List<Object[]> getCategoryBreakdown(@Param("userId") UUID userId,
                                         @Param("from") LocalDate from,
                                         @Param("to") LocalDate to);
}
