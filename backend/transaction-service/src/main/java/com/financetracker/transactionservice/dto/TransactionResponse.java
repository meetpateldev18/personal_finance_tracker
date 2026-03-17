package com.financetracker.transactionservice.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
public class TransactionResponse {
    private UUID id;
    private UUID userId;
    private UUID categoryId;
    private String type;
    private BigDecimal amount;
    private String currency;
    private String description;
    private String merchant;
    private String receiptUrl;
    private LocalDate transactionDate;
    private Boolean isFlagged;
    private Instant createdAt;
}
