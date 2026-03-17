package com.financetracker.aiservice.dto;

import lombok.Builder;
import lombok.Data;
import java.time.Instant;

@Data
@Builder
public class InsightResponse {
    private String type;
    private String content;
    private Instant generatedAt;
}
