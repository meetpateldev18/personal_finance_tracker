package com.financetracker.userservice.dto;

import lombok.Builder;
import lombok.Data;

import java.util.UUID;

@Data
@Builder
public class TokenResponse {
    private String accessToken;
    private String refreshToken;
    private long expiresInSeconds;
    private String tokenType;
    private UUID userId;
    private String email;
    private String role;
}
