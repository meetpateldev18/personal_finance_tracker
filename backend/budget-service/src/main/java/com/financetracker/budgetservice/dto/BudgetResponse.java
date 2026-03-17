package com.financetracker.budgetservice.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
public class BudgetResponse {
    private UUID id;
    private UUID userId;
    private UUID categoryId;
    private String name;
    private BigDecimal amount;
    private BigDecimal spentAmount;
    private double usagePercentage;
    private String period;
    private LocalDate startDate;
    private LocalDate endDate;
    private Integer alertThresholdPct;
    private Boolean isActive;
    private Instant createdAt;
}


import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
public class BudgetResponse {
    private UUID id;
    private UUID userId;
    private UUID categoryId;
    private String name;
    private BigDecimal amount;
    private BigDecimal spentAmount;
    private double usagePercentage;
    private String period;
    private LocalDate startDate;
    private LocalDate endDate;
    private Integer alertThresholdPct;
    private Boolean isActive;
    private Instant createdAt;
}


import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
public class BudgetResponse {
    private UUID id;
    private UUID userId;
    private UUID categoryId;
    private String name;
    private BigDecimal amount;
    private BigDecimal spentAmount;
    private double usagePercentage;
    private String period;
    private LocalDate startDate;
    private LocalDate endDate;
    private Integer alertThresholdPct;
    private Boolean isActive;
    private Instant createdAt;
}
