package com.financetracker.analyticsservice.controller;

import com.financetracker.analyticsservice.dto.AnalyticsSummaryResponse;
import com.financetracker.analyticsservice.dto.CategoryBreakdownResponse;
import com.financetracker.analyticsservice.service.AnalyticsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/analytics")
@RequiredArgsConstructor
@Tag(name = "Analytics", description = "Spending analytics and financial reports")
@SecurityRequirement(name = "bearerAuth")
public class AnalyticsController {

    private final AnalyticsService analyticsService;

    @GetMapping("/summary")
    @Operation(summary = "Get spending summary for a date range")
    public ResponseEntity<AnalyticsSummaryResponse> getSummary(
            @AuthenticationPrincipal String userId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(
                analyticsService.getSummary(UUID.fromString(userId), from, to));
    }

    @GetMapping("/category-breakdown")
    @Operation(summary = "Get expense breakdown by category")
    public ResponseEntity<List<CategoryBreakdownResponse>> getCategoryBreakdown(
            @AuthenticationPrincipal String userId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(
                analyticsService.getCategoryBreakdown(UUID.fromString(userId), from, to));
    }

    @GetMapping("/monthly-trend")
    @Operation(summary = "Get monthly income vs expense trend for last N months")
    public ResponseEntity<?> getMonthlyTrend(
            @AuthenticationPrincipal String userId,
            @RequestParam(defaultValue = "6") int months) {
        return ResponseEntity.ok(
                analyticsService.getMonthlyTrend(UUID.fromString(userId), months));
    }
}
