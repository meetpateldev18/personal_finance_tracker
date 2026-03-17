package com.financetracker.notificationservice.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;

import java.util.List;
import java.util.Map;

/**
 * Consumes notification events from SQS and dispatches Slack messages.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationQueueConsumer {

    private final SqsClient sqsClient;
    private final SlackService slackService;
    private final SlackIntegrationService slackIntegrationService;
    private final ObjectMapper objectMapper;

    @Value("${aws.sqs.notification-queue:}")
    private String notificationQueue;

    /**
     * Polls every 10 seconds for notification events from SQS.
     */
    @Scheduled(fixedDelay = 10_000)
    public void processNotifications() {
        if (notificationQueue == null || notificationQueue.isBlank()) return;

        try {
            List<Message> messages = sqsClient.receiveMessage(
                    ReceiveMessageRequest.builder()
                            .queueUrl(notificationQueue)
                            .maxNumberOfMessages(10)
                            .waitTimeSeconds(5)
                            .build()
            ).messages();

            for (Message msg : messages) {
                try {
                    dispatch(msg.body());
                    sqsClient.deleteMessage(DeleteMessageRequest.builder()
                            .queueUrl(notificationQueue)
                            .receiptHandle(msg.receiptHandle())
                            .build());
                } catch (Exception e) {
                    log.error("Failed to process notification: {}", e.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Error polling notification queue: {}", e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private void dispatch(String body) throws Exception {
        Map<String, Object> event = objectMapper.readValue(body, Map.class);
        String eventType = (String) event.get("eventType");
        String userId = (String) event.get("userId");

        // Look up the user's Slack channel ID from the integration table
        String slackChannelId = slackIntegrationService.getSlackChannelId(userId);
        if (slackChannelId == null) {
            log.debug("No Slack integration for user {}", userId);
            return;
        }

        switch (eventType) {
            case "BUDGET_ALERT" -> {
                String message = (String) event.get("message");
                String alertType = (String) event.get("alertType");
                slackService.sendDirectMessage(slackChannelId, message);
                log.info("Sent {} alert to user {}", alertType, userId);
            }
            case "LARGE_TRANSACTION" -> {
                String merchant = (String) event.get("merchant");
                double amount = ((Number) event.get("amount")).doubleValue();
                String category = (String) event.getOrDefault("category", "Other");
                slackService.sendLargeTransactionAlert(slackChannelId, merchant, amount, category);
            }
            case "WEEKLY_REPORT" -> {
                String weekLabel = (String) event.get("weekLabel");
                double income = ((Number) event.get("totalIncome")).doubleValue();
                double expense = ((Number) event.get("totalExpense")).doubleValue();
                double savings = income - expense;
                String topCategories = (String) event.getOrDefault("topCategories", "");
                slackService.sendWeeklyReport(slackChannelId, weekLabel, income, expense, savings, topCategories);
            }
            default -> log.warn("Unknown event type: {}", eventType);
        }
    }
}
