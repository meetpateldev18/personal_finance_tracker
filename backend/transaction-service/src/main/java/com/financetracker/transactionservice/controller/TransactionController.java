package com.financetracker.transactionservice.controller;

import com.financetracker.transactionservice.dto.TransactionRequest;
import com.financetracker.transactionservice.dto.TransactionResponse;
import com.financetracker.transactionservice.service.TransactionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/transactions")
@RequiredArgsConstructor
@Tag(name = "Transactions", description = "Income and expense management")
@SecurityRequirement(name = "bearerAuth")
public class TransactionController {

    private final TransactionService transactionService;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Create a new transaction (optionally with receipt)")
    public ResponseEntity<TransactionResponse> create(
            @AuthenticationPrincipal String userId,
            @RequestPart("transaction") @Valid TransactionRequest request,
            @RequestPart(value = "receipt", required = false) MultipartFile receipt) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transactionService.create(UUID.fromString(userId), request, receipt));
    }

    @GetMapping
    @Operation(summary = "Get all transactions (paginated)")
    public ResponseEntity<Page<TransactionResponse>> getAll(
            @AuthenticationPrincipal String userId,
            @PageableDefault(size = 20, sort = "transactionDate") Pageable pageable) {
        return ResponseEntity.ok(
                transactionService.getAll(UUID.fromString(userId), pageable));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get transaction by ID")
    public ResponseEntity<TransactionResponse> getById(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        return ResponseEntity.ok(
                transactionService.getById(UUID.fromString(userId), id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a transaction")
    public ResponseEntity<TransactionResponse> update(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id,
            @Valid @RequestBody TransactionRequest request) {
        return ResponseEntity.ok(
                transactionService.update(UUID.fromString(userId), id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a transaction")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        transactionService.delete(UUID.fromString(userId), id);
        return ResponseEntity.noContent().build();
    }
}
package com.financetracker.transactionservice.controller;

import com.financetracker.transactionservice.dto.TransactionRequest;
import com.financetracker.transactionservice.dto.TransactionResponse;
import com.financetracker.transactionservice.service.TransactionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/transactions")
@RequiredArgsConstructor
@Tag(name = "Transactions", description = "Income and expense management")
@SecurityRequirement(name = "bearerAuth")
public class TransactionController {

    private final TransactionService transactionService;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Create a new transaction (optionally with receipt)")
    public ResponseEntity<TransactionResponse> create(
            @AuthenticationPrincipal String userId,
            @RequestPart("transaction") @Valid TransactionRequest request,
            @RequestPart(value = "receipt", required = false) MultipartFile receipt) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transactionService.create(UUID.fromString(userId), request, receipt));
    }

    @GetMapping
    @Operation(summary = "Get all transactions (paginated)")
    public ResponseEntity<Page<TransactionResponse>> getAll(
            @AuthenticationPrincipal String userId,
            @PageableDefault(size = 20, sort = "transactionDate") Pageable pageable) {
        return ResponseEntity.ok(
                transactionService.getAll(UUID.fromString(userId), pageable));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get transaction by ID")
    public ResponseEntity<TransactionResponse> getById(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        return ResponseEntity.ok(
                transactionService.getById(UUID.fromString(userId), id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a transaction")
    public ResponseEntity<TransactionResponse> update(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id,
            @Valid @RequestBody TransactionRequest request) {
        return ResponseEntity.ok(
                transactionService.update(UUID.fromString(userId), id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a transaction")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal String userId,
            @PathVariable UUID id) {
        transactionService.delete(UUID.fromString(userId), id);
        return ResponseEntity.noContent().build();
    }
}
