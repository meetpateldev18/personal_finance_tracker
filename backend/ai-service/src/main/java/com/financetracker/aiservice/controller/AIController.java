package com.financetracker.aiservice.controller;

import com.financetracker.aiservice.dto.InsightRequest;
import com.financetracker.aiservice.dto.InsightResponse;
import com.financetracker.aiservice.service.ClaudeAIService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
@Tag(name = "AI Insights", description = "Claude Sonnet-powered financial analysis")
@SecurityRequirement(name = "bearerAuth")
public class AIController {

    private final ClaudeAIService claudeAIService;

    @PostMapping("/spending-analysis")
    @Operation(summary = "Analyze last 30 days spending patterns")
    public ResponseEntity<InsightResponse> analyzeSpending(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        Map<String, Double> categorySpending = (Map<String, Double>) body.get("categorySpending");
        double income = ((Number) body.getOrDefault("totalIncome", 0)).doubleValue();
        double expense = ((Number) body.getOrDefault("totalExpense", 0)).doubleValue();

        String insight = claudeAIService.analyzeSpendingPatterns(categorySpending, income, expense);
        return ResponseEntity.ok(InsightResponse.builder()
                .type("SPENDING_ANALYSIS")
                .content(insight)
                .generatedAt(Instant.now())
                .build());
    }

    @PostMapping("/budget-recommendations")
    @Operation(summary = "Get AI-powered budget recommendations")
    public ResponseEntity<InsightResponse> getBudgetRecommendations(
            @AuthenticationPrincipal String userId,
            @Valid @RequestBody InsightRequest request) {
        String insight = claudeAIService.generateBudgetRecommendations(
                request.getMonthlyIncome(),
                request.getCategorySpending(),
                request.getCurrentBudgets());
        return ResponseEntity.ok(InsightResponse.builder()
                .type("BUDGET_RECOMMENDATION")
                .content(insight)
                .generatedAt(Instant.now())
                .build());
    }

    @PostMapping("/unusual-spending")
    @Operation(summary = "Detect unusual spending behavior")
    public ResponseEntity<InsightResponse> detectUnusual(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        Map<String, Double> thisMonth = (Map<String, Double>) body.get("thisMonth");
        @SuppressWarnings("unchecked")
        Map<String, Double> avgMonthly = (Map<String, Double>) body.get("avgMonthly");

        String insight = claudeAIService.detectUnusualSpending(thisMonth, avgMonthly);
        return ResponseEntity.ok(InsightResponse.builder()
                .type("UNUSUAL_SPENDING")
                .content(insight)
                .generatedAt(Instant.now())
                .build());
    }

    @PostMapping("/health-score")
    @Operation(summary = "Generate monthly financial health score")
    public ResponseEntity<InsightResponse> getHealthScore(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        double income = ((Number) body.getOrDefault("income", 0)).doubleValue();
        double expenses = ((Number) body.getOrDefault("expenses", 0)).doubleValue();
        double savings = income - expenses;
        double adherence = ((Number) body.getOrDefault("budgetAdherencePct", 0)).doubleValue();
        int days = ((Number) body.getOrDefault("daysTracked", 30)).intValue();

        String insight = claudeAIService.generateMonthlyHealthScore(
                income, expenses, savings, adherence, days);
        return ResponseEntity.ok(InsightResponse.builder()
                .type("MONTHLY_HEALTH")
                .content(insight)
                .generatedAt(Instant.now())
                .build());
    }

    @PostMapping("/ask")
    @Operation(summary = "Ask a natural language question about your finances")
    public ResponseEntity<InsightResponse> askQuestion(
            @AuthenticationPrincipal String userId,
            @RequestBody Map<String, Object> body) {
        String question = (String) body.get("question");
        @SuppressWarnings("unchecked")
        Map<String, Double> spending = (Map<String, Double>) body.getOrDefault(
                "recentSpending", Map.of());
        double balance = ((Number) body.getOrDefault("currentBalance", 0)).doubleValue();

        String answer = claudeAIService.answerFinancialQuestion(question, spending, balance);
        return ResponseEntity.ok(InsightResponse.builder()
                .type("CUSTOM_QUERY")
                .content(answer)
                .generatedAt(Instant.now())
                .build());
    }
}
