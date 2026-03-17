package com.financetracker.transactionservice.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Data
public class TransactionRequest {

    @NotNull(message = "Type is required")
    @Pattern(regexp = "INCOME|EXPENSE|TRANSFER", message = "Type must be INCOME, EXPENSE, or TRANSFER")
    private String type;

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.01", message = "Amount must be greater than 0")
    @Digits(integer = 13, fraction = 2)
    private BigDecimal amount;

    private UUID categoryId;
    private String currency;
    private String description;
    private String merchant;
    private LocalDate transactionDate;
    private Boolean isRecurring;
    private String recurrenceRule;
    private String location;
    private String notes;
}
