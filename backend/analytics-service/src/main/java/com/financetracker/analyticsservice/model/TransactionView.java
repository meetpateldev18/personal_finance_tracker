package com.financetracker.analyticsservice.model;

import jakarta.persistence.*;
import lombok.Getter;
import org.hibernate.annotations.Immutable;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Read-only JPA entity mapped to the transactions table.
 * Analytics service shares the same DB but never writes.
 */
@Entity
@Table(name = "transactions")
@Immutable
@Getter
public class TransactionView {

    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "category_id")
    private UUID categoryId;

    private String type;

    private BigDecimal amount;

    private String currency;

    @Column(name = "transaction_date")
    private LocalDate transactionDate;
}
