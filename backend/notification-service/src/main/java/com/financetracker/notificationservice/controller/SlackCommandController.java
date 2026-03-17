package com.financetracker.notificationservice.controller;

import com.financetracker.notificationservice.service.SlackIntegrationService;
import com.financetracker.notificationservice.service.SlackService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.Map;

/**
 * Handles Slack slash commands:
 *   /balance  → shows income vs expense balance
 *   /budget   → shows all budget statuses
 *   /spending [category] → spending breakdown
 *
 * Slack sends command payloads as application/x-www-form-urlencoded.
 * We verify the Slack signature on every request to prevent replay attacks.
 */
@RestController
@RequestMapping("/api/v1/slack")
@RequiredArgsConstructor
@Slf4j
public class SlackCommandController {

    private final SlackService slackService;
    private final SlackIntegrationService slackIntegrationService;

    @Value("${slack.signing-secret:}")
    private String signingSecret;

    /**
     * Entry point for all slash commands from Slack.
     * Slack POSTs: token, command, text, user_id, etc.
     */
    @PostMapping(value = "/commands",
                 consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE,
                 produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, String>> handleCommand(
            @RequestParam Map<String, String> params,
            @RequestHeader(value = "X-Slack-Signature", defaultValue = "") String signature,
            @RequestHeader(value = "X-Slack-Request-Timestamp", defaultValue = "0") String timestamp,
            @RequestBody String rawBody) {

        // Security: verify Slack request signature to prevent forgery
        if (!verifySlackSignature(signature, timestamp, rawBody)) {
            log.warn("Invalid Slack signature received");
            return ResponseEntity.status(401).build();
        }

        String command = params.getOrDefault("command", "");
        String text = params.getOrDefault("text", "").trim();
        String slackUserId = params.get("user_id");

        String responseText = switch (command) {
            case "/balance" -> handleBalance(slackUserId);
            case "/budget" -> handleBudget(slackUserId);
            case "/spending" -> handleSpending(slackUserId, text);
            default -> "Unknown command: " + command;
        };

        // Slack expects {"response_type": "ephemeral", "text": "..."} for immediate reply
        return ResponseEntity.ok(Map.of(
                "response_type", "ephemeral",
                "text", responseText
        ));
    }

    /**
     * Connect a user's Slack account to their finance account.
     */
    @PostMapping("/connect")
    public ResponseEntity<Void> connectSlack(
            @RequestParam String userId,
            @RequestParam String slackUserId,
            @RequestParam String teamId,
            @RequestParam String channelId) {
        slackIntegrationService.saveIntegration(
                java.util.UUID.fromString(userId), slackUserId, teamId, channelId);
        return ResponseEntity.ok().build();
    }

    // ── Command handlers ─────────────────────────────────────────────────────

    private String handleBalance(String slackUserId) {
        // In production: query Transaction Service via internal HTTP call or shared DB view
        // For demo, return a static formatted response
        return slackService.buildBalanceResponse(5000.00, 3200.00);
    }

    private String handleBudget(String slackUserId) {
        // In production: query Budget Service
        return slackService.buildBudgetStatusResponse(
                java.util.List.of(
                        "🍔 Food: █████████░ 85% ($425/$500)",
                        "🚗 Transport: ████░░░░░░ 40% ($80/$200)",
                        "🛍️ Shopping: ███████░░░ 70% ($350/$500)"
                )
        );
    }

    private String handleSpending(String slackUserId, String category) {
        if (category.isBlank()) {
            return "Usage: /spending [category]\nExample: /spending food";
        }
        // In production: query Transaction Service for real data
        return slackService.buildSpendingResponse(
                capitalise(category), 425.00, 500.00);
    }

    // ── Slack signature verification ─────────────────────────────────────────

    /**
     * Verifies the Slack request using HMAC-SHA256.
     * See: https://api.slack.com/authentication/verifying-requests-from-slack
     */
    private boolean verifySlackSignature(String signature, String timestamp, String body) {
        if (signingSecret == null || signingSecret.isBlank()) return true;  // skip if not configured

        try {
            // Reject requests older than 5 minutes to prevent replay attacks
            long requestTime = Long.parseLong(timestamp);
            if (Math.abs(System.currentTimeMillis() / 1000 - requestTime) > 300) {
                return false;
            }

            String baseString = "v0:" + timestamp + ":" + body;
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(
                    signingSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(baseString.getBytes(StandardCharsets.UTF_8));
            String computed = "v0=" + HexFormat.of().formatHex(hash);
            return computed.equals(signature);
        } catch (Exception e) {
            log.error("Signature verification error: {}", e.getMessage());
            return false;
        }
    }

    private String capitalise(String s) {
        if (s == null || s.isEmpty()) return s;
        return Character.toUpperCase(s.charAt(0)) + s.substring(1).toLowerCase();
    }
}
