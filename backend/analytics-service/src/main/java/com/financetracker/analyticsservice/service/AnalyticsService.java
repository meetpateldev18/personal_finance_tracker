package com.financetracker.analyticsservice.service;

import com.financetracker.analyticsservice.dto.AnalyticsSummaryResponse;
import com.financetracker.analyticsservice.dto.CategoryBreakdownResponse;
import com.financetracker.analyticsservice.dto.MonthlyTrendResponse;
import com.financetracker.analyticsservice.repository.AnalyticsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AnalyticsService {

    private final AnalyticsRepository analyticsRepository;

    public AnalyticsSummaryResponse getSummary(UUID userId, LocalDate from, LocalDate to) {
        BigDecimal totalIncome = analyticsRepository.sumByType(userId, "INCOME", from, to);
        BigDecimal totalExpense = analyticsRepository.sumByType(userId, "EXPENSE", from, to);

        totalIncome = totalIncome != null ? totalIncome : BigDecimal.ZERO;
        totalExpense = totalExpense != null ? totalExpense : BigDecimal.ZERO;
        BigDecimal savings = totalIncome.subtract(totalExpense);

        return AnalyticsSummaryResponse.builder()
                .totalIncome(totalIncome)
                .totalExpense(totalExpense)
                .netSavings(savings)
                .savingsRate(totalIncome.compareTo(BigDecimal.ZERO) > 0
                        ? savings.divide(totalIncome, 4, java.math.RoundingMode.HALF_UP)
                                  .multiply(BigDecimal.valueOf(100)).doubleValue()
                        : 0.0)
                .from(from)
                .to(to)
                .build();
    }

    public List<CategoryBreakdownResponse> getCategoryBreakdown(
            UUID userId, LocalDate from, LocalDate to) {
        return analyticsRepository.getCategoryBreakdown(userId, from, to)
                .stream()
                .map(row -> CategoryBreakdownResponse.builder()
                        .categoryId((UUID) row[0])
                        .categoryName((String) row[1])
                        .totalAmount((BigDecimal) row[2])
                        .transactionCount(((Number) row[3]).intValue())
                        .build())
                .toList();
    }

    public List<MonthlyTrendResponse> getMonthlyTrend(UUID userId, int months) {
        List<MonthlyTrendResponse> trend = new ArrayList<>();
        YearMonth current = YearMonth.now();

        for (int i = months - 1; i >= 0; i--) {
            YearMonth month = current.minusMonths(i);
            LocalDate start = month.atDay(1);
            LocalDate end = month.atEndOfMonth();

            BigDecimal income = analyticsRepository.sumByType(userId, "INCOME", start, end);
            BigDecimal expense = analyticsRepository.sumByType(userId, "EXPENSE", start, end);
            income = income != null ? income : BigDecimal.ZERO;
            expense = expense != null ? expense : BigDecimal.ZERO;

            trend.add(MonthlyTrendResponse.builder()
                    .month(month.toString())
                    .income(income)
                    .expense(expense)
                    .savings(income.subtract(expense))
                    .build());
        }
        return trend;
    }
}
