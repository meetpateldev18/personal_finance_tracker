package com.financetracker.transactionservice.repository;

import com.financetracker.transactionservice.model.Transaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, UUID> {

    Page<Transaction> findByUserIdOrderByTransactionDateDesc(UUID userId, Pageable pageable);

    Page<Transaction> findByUserIdAndTypeOrderByTransactionDateDesc(
            UUID userId, Transaction.TransactionType type, Pageable pageable);

    List<Transaction> findByUserIdAndTransactionDateBetweenOrderByTransactionDateDesc(
            UUID userId, LocalDate from, LocalDate to);

    @Query("SELECT SUM(t.amount) FROM Transaction t WHERE t.userId = :userId " +
           "AND t.type = 'EXPENSE' AND t.categoryId = :categoryId " +
           "AND t.transactionDate BETWEEN :start AND :end")
    BigDecimal sumExpensesByUserAndCategory(
            @Param("userId") UUID userId,
            @Param("categoryId") UUID categoryId,
            @Param("start") LocalDate start,
            @Param("end") LocalDate end);

    @Query("SELECT SUM(t.amount) FROM Transaction t WHERE t.userId = :userId " +
           "AND t.type = 'EXPENSE' " +
           "AND t.transactionDate BETWEEN :start AND :end")
    BigDecimal sumExpensesByUser(
            @Param("userId") UUID userId,
            @Param("start") LocalDate start,
            @Param("end") LocalDate end);

    // Velocity check: count recent transactions for fraud detection
    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.userId = :userId " +
           "AND t.createdAt >= :since")
    long countRecentTransactions(@Param("userId") UUID userId,
                                  @Param("since") java.time.Instant since);
}
