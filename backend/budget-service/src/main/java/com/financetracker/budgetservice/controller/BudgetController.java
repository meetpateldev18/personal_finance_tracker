package com.financetracker.budgetservice.controller;

import com.financetracker.budgetservice.dto.BudgetRequest;
import com.financetracker.budgetservice.dto.BudgetResponse;
import com.financetracker.budgetservice.service.BudgetService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/budgets")
@RequiredArgsConstructor
@Tag(name = "Budgets", description = "Budget management and threshold alerts")
@SecurityRequirement(name = "bearerAuth")
public class BudgetController {

    private final BudgetService budgetService;

    @PostMapping
    @Operation(summary = "Create a new budget")
    public ResponseEntity<BudgetResponse> create(
            @AuthenticationPrincipal String userId,
            @Valid @RequestBody BudgetRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(budgetService.create(UUID.fromString(userId), request));
    }

    @GetMapping
    @Operation(summary = "Get all active budgets for current user")
    public ResponseEntity<List<BudgetResponse>> getAll(@AuthenticationPrincipal String userId) {
        return ResponseEntity.ok(budgetService.getAllActive(UUID.fromString(userId)));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get budget by ID")
    public ResponseEntity<BudgetResponse> getById(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        return ResponseEntity.ok(budgetService.getById(UUID.fromString(userId), id));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Deactivate a budget")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        budgetService.delete(UUID.fromString(userId), id);
        return ResponseEntity.noContent().build();
    }
}

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/budgets")
@RequiredArgsConstructor
@Tag(name = "Budgets", description = "Budget management and threshold alerts")
@SecurityRequirement(name = "bearerAuth")
public class BudgetController {

    private final BudgetService budgetService;

    @PostMapping
    @Operation(summary = "Create a new budget")
    public ResponseEntity<BudgetResponse> create(
            @AuthenticationPrincipal String userId,
            @Valid @RequestBody BudgetRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(budgetService.create(UUID.fromString(userId), request));
    }

    @GetMapping
    @Operation(summary = "Get all active budgets for current user")
    public ResponseEntity<List<BudgetResponse>> getAll(@AuthenticationPrincipal String userId) {
        return ResponseEntity.ok(budgetService.getAllActive(UUID.fromString(userId)));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get budget by ID")
    public ResponseEntity<BudgetResponse> getById(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        return ResponseEntity.ok(budgetService.getById(UUID.fromString(userId), id));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Deactivate a budget")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        budgetService.delete(UUID.fromString(userId), id);
        return ResponseEntity.noContent().build();
    }
}

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/budgets")
@RequiredArgsConstructor
@Tag(name = "Budgets", description = "Budget management and threshold alerts")
@SecurityRequirement(name = "bearerAuth")
public class BudgetController {

    private final BudgetService budgetService;

    @PostMapping
    @Operation(summary = "Create a new budget")
    public ResponseEntity<BudgetResponse> create(
            @AuthenticationPrincipal String userId,
            @Valid @RequestBody BudgetRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(budgetService.create(UUID.fromString(userId), request));
    }

    @GetMapping
    @Operation(summary = "Get all active budgets for current user")
    public ResponseEntity<List<BudgetResponse>> getAll(@AuthenticationPrincipal String userId) {
        return ResponseEntity.ok(budgetService.getAllActive(UUID.fromString(userId)));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get budget by ID")
    public ResponseEntity<BudgetResponse> getById(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        return ResponseEntity.ok(budgetService.getById(UUID.fromString(userId), id));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Deactivate a budget")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        budgetService.delete(UUID.fromString(userId), id);
        return ResponseEntity.noContent().build();
    }
}
