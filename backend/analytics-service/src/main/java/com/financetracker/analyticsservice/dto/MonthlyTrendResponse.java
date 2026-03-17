package com.financetracker.analyticsservice.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class MonthlyTrendResponse {
    private String month;  // e.g. "2025-03"
    private BigDecimal income;
    private BigDecimal expense;
    private BigDecimal savings;
}
