package com.financetracker.aiservice.dto;

import lombok.Data;
import java.util.List;
import java.util.Map;

@Data
public class InsightRequest {
    private double monthlyIncome;
    private Map<String, Double> categorySpending;
    private List<String> currentBudgets;
    private String question;
}
