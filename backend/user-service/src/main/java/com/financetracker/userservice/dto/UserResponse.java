package com.financetracker.userservice.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class UserResponse {
    private UUID id;
    private String email;
    private String username;
    private String fullName;
    private String phoneNumber;
    private String avatarUrl;
    private String currency;
    private String timezone;
    private BigDecimal monthlyIncome;
    private String role;
    private Boolean isEmailVerified;
    private Instant createdAt;
}
