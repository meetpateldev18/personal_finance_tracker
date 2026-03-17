package com.financetracker.notificationservice.scheduler;

import com.financetracker.notificationservice.model.SlackIntegration;
import com.financetracker.notificationservice.repository.SlackIntegrationRepository;
import com.financetracker.notificationservice.service.SlackService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Scheduled jobs for periodic Slack notifications:
 *   - Daily summary at 9pm (configurable per user in preferences)
 *   - Weekly report every Sunday at 8am
 *   - Monthly budget reset notification on 1st of each month
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class NotificationScheduler {

    private final SlackIntegrationRepository slackIntegrationRepository;
    private final SlackService slackService;

    /**
     * Daily spending summary — runs every day at 21:00 UTC.
     * In production: query Transaction Service for actual data per user.
     */
    @Scheduled(cron = "0 0 21 * * *")
    public void sendDailySummaries() {
        log.info("Sending daily spending summaries...");
        List<SlackIntegration> integrations = slackIntegrationRepository.findAll()
                .stream().filter(SlackIntegration::getIsActive).toList();

        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("MMMM d, yyyy"));

        for (SlackIntegration integration : integrations) {
            try {
                // TODO: Replace with real data query from Transaction Service
                slackService.sendDailySummary(
                        integration.getSlackChannelId(),
                        today,
                        85.50,  // placeholder
                        "• 🍔 Food: $35.00\n• 🚗 Transport: $20.50\n• ☕ Coffee: $30.00"
                );
            } catch (Exception e) {
                log.error("Failed to send daily summary to user {}: {}",
                        integration.getUserId(), e.getMessage());
            }
        }
    }

    /**
     * Weekly report — runs every Sunday at 08:00 UTC.
     */
    @Scheduled(cron = "0 0 8 * * SUN")
    public void sendWeeklyReports() {
        log.info("Sending weekly financial reports...");
        List<SlackIntegration> integrations = slackIntegrationRepository.findAll()
                .stream().filter(SlackIntegration::getIsActive).toList();

        LocalDate weekEnd = LocalDate.now();
        LocalDate weekStart = weekEnd.minusDays(6);
        String weekLabel = weekStart.format(DateTimeFormatter.ofPattern("MMM d")) +
                " – " + weekEnd.format(DateTimeFormatter.ofPattern("MMM d, yyyy"));

        for (SlackIntegration integration : integrations) {
            try {
                // TODO: Replace with real data from Transaction Service
                slackService.sendWeeklyReport(
                        integration.getSlackChannelId(),
                        weekLabel,
                        2500.00,   // income placeholder
                        1200.00,   // expense placeholder
                        1300.00,   // savings placeholder
                        "1. 🍔 Food: $450\n2. 🛍️ Shopping: $320\n3. 🚗 Transport: $180"
                );
            } catch (Exception e) {
                log.error("Failed to send weekly report to user {}: {}",
                        integration.getUserId(), e.getMessage());
            }
        }
    }

    /**
     * Monthly budget reset notification — runs on the 1st of every month at 07:00 UTC.
     */
    @Scheduled(cron = "0 0 7 1 * *")
    public void sendMonthlyBudgetReset() {
        log.info("Sending monthly budget reset notifications...");
        List<SlackIntegration> integrations = slackIntegrationRepository.findAll()
                .stream().filter(SlackIntegration::getIsActive).toList();

        String monthName = LocalDate.now().format(DateTimeFormatter.ofPattern("MMMM yyyy"));

        for (SlackIntegration integration : integrations) {
            try {
                slackService.sendDirectMessage(
                        integration.getSlackChannelId(),
                        "🔄 *New Month, Fresh Budgets!*\n" +
                        "Your budgets have been reset for *" + monthName + "*. " +
                        "Start the month strong! Open the app to review your budget plan."
                );
            } catch (Exception e) {
                log.error("Failed to send monthly reset to user {}: {}",
                        integration.getUserId(), e.getMessage());
            }
        }
    }
}
