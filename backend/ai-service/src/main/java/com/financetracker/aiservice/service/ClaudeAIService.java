package com.financetracker.aiservice.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * Integrates with Anthropic's Claude Sonnet API for financial insights.
 *
 * API Reference: https://docs.anthropic.com/en/api/messages
 *
 * Key behaviours:
 *   - Caches identical prompts in Redis for 60 min to reduce API costs
 *   - Uses a system prompt that focuses Claude on personal finance
 *   - Returns structured insights or raw narrative text
 */
@Service
@Slf4j
public class ClaudeAIService {

    private static final String CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
    private static final String ANTHROPIC_VERSION = "2023-06-01";

    private final OkHttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final RedisTemplate<String, String> redisTemplate;

    @Value("${anthropic.api-key}")
    private String apiKey;

    @Value("${anthropic.model:claude-3-5-sonnet-20241022}")
    private String model;

    @Value("${anthropic.max-tokens:1024}")
    private int maxTokens;

    @Value("${anthropic.cache-ttl-minutes:60}")
    private long cacheTtlMinutes;

    private static final String SYSTEM_PROMPT = """
            You are a personal finance advisor AI assistant embedded in a finance tracking app.
            Your role is to analyze spending patterns, provide actionable budget recommendations,
            detect unusual financial behavior, and give personalized financial health insights.

            Guidelines:
            - Be concise, practical, and encouraging
            - Use specific numbers from the data provided
            - Highlight both positives and areas for improvement
            - Suggest 2-3 concrete action items
            - Use simple language (avoid jargon)
            - Format responses with clear sections when appropriate
            - Never reveal that you are Claude or an AI unless directly asked
            """;

    public ClaudeAIService(ObjectMapper objectMapper,
                            RedisTemplate<String, String> redisTemplate) {
        this.objectMapper = objectMapper;
        this.redisTemplate = redisTemplate;
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .build();
    }

    /**
     * Analyze spending patterns for the last 30 days.
     * Returns a natural language summary with recommendations.
     */
    public String analyzeSpendingPatterns(Map<String, Double> categorySpending,
                                           double totalIncome, double totalExpense) {
        String prompt = buildSpendingAnalysisPrompt(categorySpending, totalIncome, totalExpense);
        return callClaude(prompt, "spending_analysis:" + prompt.hashCode());
    }

    /**
     * Generate budget recommendations based on income and spending history.
     */
    public String generateBudgetRecommendations(double monthlyIncome,
                                                  Map<String, Double> averageSpending,
                                                  List<String> currentBudgets) {
        String prompt = String.format("""
                Monthly income: $%.2f
                Average monthly spending by category: %s
                Current budget setup: %s

                Based on the 50/30/20 rule and this person's actual spending:
                1. Evaluate if their current budgets are realistic
                2. Suggest specific budget amounts for each major category
                3. Identify 2-3 areas where they could save more
                4. Give a savings target for next month
                """,
                monthlyIncome,
                formatCategoryMap(averageSpending),
                String.join(", ", currentBudgets));

        return callClaude(prompt, "budget_rec:" + prompt.hashCode());
    }

    /**
     * Detect unusual spending behavior compared to historical averages.
     */
    public String detectUnusualSpending(Map<String, Double> thisMonthSpending,
                                         Map<String, Double> avgMonthlySpending) {
        StringBuilder sb = new StringBuilder("This month vs average monthly spending:\n");
        thisMonthSpending.forEach((cat, amount) -> {
            double avg = avgMonthlySpending.getOrDefault(cat, 0.0);
            double diff = amount - avg;
            sb.append(String.format("- %s: $%.2f (avg: $%.2f, diff: %+.2f)\n",
                    cat, amount, avg, diff));
        });

        String prompt = sb + "\nIdentify any unusual spikes or drops. " +
                "Flag categories where spending is more than 50% above average. " +
                "Provide possible explanations and advice.";

        return callClaude(prompt, "unusual:" + prompt.hashCode());
    }

    /**
     * Generate a monthly financial health score (0-100) with explanation.
     */
    public String generateMonthlyHealthScore(double income, double expenses,
                                              double savings, double budgetAdherencePct,
                                              int daysWithTransactions) {
        double savingsRate = income > 0 ? (savings / income) * 100 : 0;

        String prompt = String.format("""
                Monthly Financial Health Report Data:
                - Total Income: $%.2f
                - Total Expenses: $%.2f
                - Net Savings: $%.2f (%.1f%% savings rate)
                - Budget Adherence: %.1f%% of budgets stayed within limits
                - Active days tracked: %d/30

                Please provide:
                1. A financial health score from 0-100 (format: "Score: XX/100")
                2. A 2-sentence assessment of their financial health
                3. Top 3 strengths
                4. Top 2 areas for improvement
                5. One specific goal for next month
                """,
                income, expenses, savings, savingsRate,
                budgetAdherencePct, daysWithTransactions);

        return callClaude(prompt, "health_score:" + prompt.hashCode());
    }

    /**
     * Answer a natural language question about personal finances.
     * E.g., "How much did I spend on food last month?" or "Can I afford a $500 purchase?"
     */
    public String answerFinancialQuestion(String question,
                                           Map<String, Double> recentSpending,
                                           double currentBalance) {
        String prompt = String.format("""
                User's financial context:
                - Current estimated balance: $%.2f
                - Recent spending (last 30 days): %s

                User's question: %s

                Answer concisely and helpfully based on the data provided.
                If the data is insufficient, say so and tell them what to track.
                """,
                currentBalance,
                formatCategoryMap(recentSpending),
                question);

        // Don't cache Q&A responses — they're highly contextual
        return callClaude(prompt, null);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private String callClaude(String userMessage, String cacheKey) {
        // Check Redis cache first
        if (cacheKey != null) {
            String cached = redisTemplate.opsForValue().get("ai_cache:" + cacheKey);
            if (cached != null) {
                log.debug("Returning cached AI response for key: {}", cacheKey);
                return cached;
            }
        }

        try {
            Map<String, Object> requestBody = Map.of(
                    "model", model,
                    "max_tokens", maxTokens,
                    "system", SYSTEM_PROMPT,
                    "messages", List.of(Map.of("role", "user", "content", userMessage))
            );

            RequestBody body = RequestBody.create(
                    objectMapper.writeValueAsString(requestBody),
                    MediaType.get("application/json; charset=utf-8")
            );

            Request request = new Request.Builder()
                    .url(CLAUDE_API_URL)
                    .addHeader("x-api-key", apiKey)
                    .addHeader("anthropic-version", ANTHROPIC_VERSION)
                    .addHeader("content-type", "application/json")
                    .post(body)
                    .build();

            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful() || response.body() == null) {
                    log.error("Claude API error: {} - {}", response.code(), response.message());
                    return "Unable to generate insights at this time. Please try again later.";
                }

                String responseBody = response.body().string();
                JsonNode json = objectMapper.readTree(responseBody);

                // Extract text from Claude's response
                String content = json.path("content")
                        .path(0)
                        .path("text")
                        .asText("No response generated.");

                // Cache the result
                if (cacheKey != null && !content.isBlank()) {
                    redisTemplate.opsForValue().set(
                            "ai_cache:" + cacheKey, content,
                            cacheTtlMinutes, TimeUnit.MINUTES);
                }

                return content;
            }
        } catch (IOException e) {
            log.error("Failed to call Claude API: {}", e.getMessage());
            return "Unable to generate insights at this time. Please try again later.";
        }
    }

    private String buildSpendingAnalysisPrompt(Map<String, Double> categorySpending,
                                                double income, double expense) {
        return String.format("""
                Last 30 days financial data:
                - Total Income: $%.2f
                - Total Expenses: $%.2f
                - Net: $%.2f

                Spending by category:
                %s

                Please provide:
                1. A brief summary of spending patterns
                2. Top 3 insights about spending habits
                3. 3 specific, actionable recommendations to improve finances
                4. Encouragement if they're doing well, or gentle advice if overspending
                """,
                income, expense, income - expense,
                formatCategoryMap(categorySpending));
    }

    private String formatCategoryMap(Map<String, Double> map) {
        StringBuilder sb = new StringBuilder();
        map.entrySet().stream()
                .sorted(Map.Entry.<String, Double>comparingByValue().reversed())
                .forEach(e -> sb.append(String.format("  - %s: $%.2f\n", e.getKey(), e.getValue())));
        return sb.toString();
    }
}
