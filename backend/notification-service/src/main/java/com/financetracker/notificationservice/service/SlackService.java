package com.financetracker.notificationservice.service;

import com.slack.api.Slack;
import com.slack.api.methods.MethodsClient;
import com.slack.api.methods.SlackApiException;
import com.slack.api.methods.request.chat.ChatPostMessageRequest;
import com.slack.api.model.block.Blocks;
import com.slack.api.model.block.LayoutBlock;
import com.slack.api.model.block.composition.BlockCompositions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.List;

/**
 * Wraps the Slack API for sending messages, DMs, and handling slash commands.
 *
 * Bot Token Scopes needed:
 *   chat:write        – post messages
 *   im:write          – open DM conversations
 *   commands          – respond to slash commands
 *   users:read        – look up user info by Slack user ID
 */
@Service
@Slf4j
public class SlackService {

    private final MethodsClient slack;

    public SlackService(@Value("${slack.bot-token:}") String botToken) {
        this.slack = Slack.getInstance().methods(botToken);
    }

    /**
     * Send a plain text DM to a Slack user.
     */
    public void sendDirectMessage(String slackUserId, String text) {
        try {
            var response = slack.chatPostMessage(ChatPostMessageRequest.builder()
                    .channel(slackUserId)   // Slack accepts user ID as channel for DMs
                    .text(text)
                    .build());

            if (!response.isOk()) {
                log.error("Slack DM failed: {}", response.getError());
            }
        } catch (IOException | SlackApiException e) {
            log.error("Slack API error sending DM: {}", e.getMessage());
        }
    }

    /**
     * Send a rich block-formatted message to a channel or DM.
     */
    public void sendBlockMessage(String channel, String fallbackText, List<LayoutBlock> blocks) {
        try {
            var response = slack.chatPostMessage(ChatPostMessageRequest.builder()
                    .channel(channel)
                    .text(fallbackText)
                    .blocks(blocks)
                    .build());

            if (!response.isOk()) {
                log.error("Slack block message failed: {}", response.getError());
            }
        } catch (IOException | SlackApiException e) {
            log.error("Slack API error sending blocks: {}", e.getMessage());
        }
    }

    /**
     * Send a budget alert with rich formatting.
     * Example: "⚠️ You've used 80% of your Food budget this month"
     */
    public void sendBudgetAlert(String slackUserId, String budgetName,
                                 double usagePct, double spent, double total) {
        String emoji = usagePct >= 100 ? "🚨" : "⚠️";
        String status = usagePct >= 100 ? "EXCEEDED" : String.format("%.0f%% used", usagePct);

        List<LayoutBlock> blocks = List.of(
            Blocks.section(s -> s.text(BlockCompositions.markdownText(
                String.format("%s *Budget Alert: %s*\n" +
                              "Status: *%s*\n" +
                              "Spent: *$%.2f* of *$%.2f*",
                              emoji, budgetName, status, spent, total)
            ))),
            Blocks.divider()
        );

        sendBlockMessage(slackUserId,
                emoji + " Budget Alert: " + budgetName + " is " + status, blocks);
    }

    /**
     * Send daily spending summary.
     */
    public void sendDailySummary(String slackUserId, String date,
                                  double totalSpent, String breakdown) {
        List<LayoutBlock> blocks = List.of(
            Blocks.header(h -> h.text(BlockCompositions.plainText("📊 Daily Spending Summary — " + date))),
            Blocks.section(s -> s.text(BlockCompositions.markdownText(
                String.format("*Total Spent Today:* $%.2f", totalSpent)
            ))),
            Blocks.section(s -> s.text(BlockCompositions.markdownText(breakdown))),
            Blocks.divider()
        );

        sendBlockMessage(slackUserId,
                "📊 Daily Summary: $" + String.format("%.2f", totalSpent) + " spent today", blocks);
    }

    /**
     * Send weekly financial report every Sunday.
     */
    public void sendWeeklyReport(String slackUserId, String weekLabel,
                                  double totalIncome, double totalExpense,
                                  double savings, String topCategories) {
        double savingsRate = totalIncome > 0 ? (savings / totalIncome) * 100 : 0;
        String savingsEmoji = savingsRate >= 20 ? "🟢" : savingsRate >= 10 ? "🟡" : "🔴";

        List<LayoutBlock> blocks = List.of(
            Blocks.header(h -> h.text(BlockCompositions.plainText("📈 Weekly Financial Report — " + weekLabel))),
            Blocks.section(s -> s.text(BlockCompositions.markdownText(
                String.format("*Income:* $%.2f\n*Expenses:* $%.2f\n*Net Savings:* %s $%.2f (%.1f%%)",
                        totalIncome, totalExpense, savingsEmoji, savings, savingsRate)
            ))),
            Blocks.section(s -> s.text(BlockCompositions.markdownText("*Top Categories:*\n" + topCategories))),
            Blocks.divider()
        );

        sendBlockMessage(slackUserId, "📈 Weekly Report: saved $" + String.format("%.2f", savings), blocks);
    }

    /**
     * Send large transaction alert.
     */
    public void sendLargeTransactionAlert(String slackUserId, String merchant,
                                           double amount, String category) {
        String msg = String.format("💳 *Large Transaction Alert*\n" +
                        "Amount: *$%.2f*\n" +
                        "Merchant: *%s*\n" +
                        "Category: *%s*\n" +
                        "_If this wasn't you, review your account immediately._",
                        amount, merchant != null ? merchant : "Unknown", category);

        List<LayoutBlock> blocks = List.of(
            Blocks.section(s -> s.text(BlockCompositions.markdownText(msg))),
            Blocks.divider()
        );

        sendBlockMessage(slackUserId, "💳 Large transaction: $" + amount, blocks);
    }

    /**
     * Respond to Slack slash command /balance — returns current balance info.
     * Called by SlackCommandController.
     */
    public String buildBalanceResponse(double totalIncome, double totalExpense) {
        double balance = totalIncome - totalExpense;
        String emoji = balance >= 0 ? "✅" : "❌";
        return String.format("%s *Current Balance*\nIncome: $%.2f | Expenses: $%.2f | Net: *$%.2f*",
                emoji, totalIncome, totalExpense, balance);
    }

    /**
     * Respond to Slack slash command /budget — returns all budget statuses.
     */
    public String buildBudgetStatusResponse(List<String> budgetLines) {
        if (budgetLines.isEmpty()) return "No active budgets found. Use the app to create one!";
        StringBuilder sb = new StringBuilder("📋 *Your Active Budgets:*\n\n");
        budgetLines.forEach(line -> sb.append(line).append("\n"));
        return sb.toString();
    }

    /**
     * Respond to Slack slash command /spending [category].
     */
    public String buildSpendingResponse(String category, double amount, double budgetAmount) {
        double pct = budgetAmount > 0 ? (amount / budgetAmount) * 100 : 0;
        String bar = buildProgressBar(pct);
        return String.format("🛍️ *%s Spending*\nSpent: $%.2f of $%.2f\n%s %.0f%%",
                category, amount, budgetAmount, bar, pct);
    }

    // Creates a simple ASCII progress bar
    private String buildProgressBar(double percentage) {
        int filled = (int) Math.min(percentage / 10, 10);
        return "█".repeat(filled) + "░".repeat(10 - filled);
    }
}
