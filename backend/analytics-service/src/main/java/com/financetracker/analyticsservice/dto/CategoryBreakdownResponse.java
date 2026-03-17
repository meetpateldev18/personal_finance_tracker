package com.financetracker.analyticsservice.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
public class CategoryBreakdownResponse {
    private UUID categoryId;
    private String categoryName;
    private BigDecimal totalAmount;
    private int transactionCount;
}
