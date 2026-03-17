package com.financetracker.budgetservice.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Data
public class BudgetRequest {

    @NotBlank
    @Size(max = 100)
    private String name;

    @NotNull
    @DecimalMin("0.01")
    private BigDecimal amount;

    private UUID categoryId;

    @Pattern(regexp = "WEEKLY|MONTHLY|QUARTERLY|YEARLY")
    private String period = "MONTHLY";

    @NotNull
    private LocalDate startDate;

    @NotNull
    private LocalDate endDate;

    @Min(1) @Max(100)
    private Integer alertThresholdPct = 80;

    @DecimalMin("0.01")
    private BigDecimal largeTxThreshold;

    private Boolean rolloverUnused = false;
}
