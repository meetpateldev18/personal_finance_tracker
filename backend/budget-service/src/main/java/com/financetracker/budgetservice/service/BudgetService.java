package com.financetracker.budgetservice.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.financetracker.budgetservice.dto.BudgetRequest;
import com.financetracker.budgetservice.dto.BudgetResponse;
import com.financetracker.budgetservice.exception.ResourceNotFoundException;
import com.financetracker.budgetservice.model.Budget;
import com.financetracker.budgetservice.repository.BudgetRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class BudgetService {

    private final BudgetRepository budgetRepository;
    private final SqsClient sqsClient;
    private final ObjectMapper objectMapper;

    @Value("${aws.sqs.budget-alert-queue}")
    private String budgetAlertQueue;

    @Value("${aws.sqs.notification-queue}")
    private String notificationQueue;

    @Transactional
    public BudgetResponse create(UUID userId, BudgetRequest request) {
        Budget budget = Budget.builder()
                .userId(userId)
                .categoryId(request.getCategoryId())
                .name(request.getName())
                .amount(request.getAmount())
                .period(Budget.BudgetPeriod.valueOf(request.getPeriod()))
                .startDate(request.getStartDate())
                .endDate(request.getEndDate())
                .alertThresholdPct(request.getAlertThresholdPct() != null
                        ? request.getAlertThresholdPct() : 80)
                .largeTxThreshold(request.getLargeTxThreshold())
                .rolloverUnused(request.getRolloverUnused() != null
                        && request.getRolloverUnused())
                .build();
        return mapToResponse(budgetRepository.save(budget));
    }

    public List<BudgetResponse> getAllActive(UUID userId) {
        return budgetRepository.findByUserIdAndIsActiveTrue(userId)
                .stream().map(this::mapToResponse).toList();
    }

    public BudgetResponse getById(UUID userId, UUID budgetId) {
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new ResourceNotFoundException("Budget not found"));
        if (!budget.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Budget not found");
        }
        return mapToResponse(budget);
    }

    @Transactional
    public void delete(UUID userId, UUID budgetId) {
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new ResourceNotFoundException("Budget not found"));
        if (!budget.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Budget not found");
        }
        budget.setIsActive(false);
        budgetRepository.save(budget);
    }

    /**
     * Polls the budget-alert SQS queue for transaction events published by
     * the Transaction Service, then checks thresholds and sends Slack notifications.
     * Runs every 10 seconds.
     */
    @Scheduled(fixedDelay = 10_000)
    public void processBudgetAlertQueue() {
        if (budgetAlertQueue == null || budgetAlertQueue.isBlank()) return;

        try {
            List<Message> messages = sqsClient.receiveMessage(
                    ReceiveMessageRequest.builder()
                            .queueUrl(budgetAlertQueue)
                            .maxNumberOfMessages(10)
                            .waitTimeSeconds(5)        // long polling
                            .build()
            ).messages();

            for (Message msg : messages) {
                try {
                    processTransactionEvent(msg.body());
                    // Delete from queue only after successful processing
                    sqsClient.deleteMessage(DeleteMessageRequest.builder()
                            .queueUrl(budgetAlertQueue)
                            .receiptHandle(msg.receiptHandle())
                            .build());
                } catch (Exception e) {
                    log.error("Error processing budget alert message: {}", e.getMessage());
                    // Message will become visible again after visibility timeout
                }
            }
        } catch (Exception e) {
            log.error("Error polling budget alert queue: {}", e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private void processTransactionEvent(String messageBody) throws Exception {
        Map<String, Object> event = objectMapper.readValue(messageBody, Map.class);

        String userIdStr = (String) event.get("userId");
        String categoryIdStr = (String) event.get("categoryId");
        double amount = ((Number) event.get("amount")).doubleValue();
        String type = (String) event.get("type");

        if (!"EXPENSE".equals(type)) return;  // only expenses affect budgets

        UUID userId = UUID.fromString(userIdStr);
        UUID categoryId = categoryIdStr != null ? UUID.fromString(categoryIdStr) : null;

        // Find active budgets for this user/category
        List<Budget> budgets = budgetRepository.findActiveBudgetsForUserAndCategory(
                userId, categoryId, LocalDate.now());

        for (Budget budget : budgets) {
            BigDecimal newSpent = budget.getSpentAmount()
                    .add(BigDecimal.valueOf(amount));
            budget.setSpentAmount(newSpent);
            budgetRepository.save(budget);

            double usagePct = budget.getUsagePercentage();
            checkAndSendThresholdAlert(budget, usagePct);
        }
    }

    private void checkAndSendThresholdAlert(Budget budget, double usagePct) {
        int threshold = budget.getAlertThresholdPct();
        if (usagePct >= 100) {
            sendNotificationEvent(budget, "EXCEEDED",
                    String.format("🚨 Budget EXCEEDED: *%s* is %.1f%% used ($%.2f of $%.2f)",
                            budget.getName(), usagePct,
                            budget.getSpentAmount(), budget.getAmount()));
        } else if (usagePct >= threshold) {
            sendNotificationEvent(budget, "THRESHOLD",
                    String.format("⚠️ Budget Alert: *%s* is %.0f%% used ($%.2f of $%.2f)",
                            budget.getName(), usagePct,
                            budget.getSpentAmount(), budget.getAmount()));
        }
    }

    private void sendNotificationEvent(Budget budget, String alertType, String message) {
        try {
            Map<String, Object> notification = new HashMap<>();
            notification.put("eventType", "BUDGET_ALERT");
            notification.put("userId", budget.getUserId().toString());
            notification.put("budgetId", budget.getId().toString());
            notification.put("alertType", alertType);
            notification.put("message", message);

            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(notificationQueue)
                    .messageBody(objectMapper.writeValueAsString(notification))
                    .build());
            log.info("Budget alert sent for budget {}: {}", budget.getId(), alertType);
        } catch (Exception e) {
            log.error("Failed to send notification event: {}", e.getMessage());
        }
    }

    private BudgetResponse mapToResponse(Budget b) {
        return BudgetResponse.builder()
                .id(b.getId())
                .userId(b.getUserId())
                .categoryId(b.getCategoryId())
                .name(b.getName())
                .amount(b.getAmount())
                .spentAmount(b.getSpentAmount())
                .usagePercentage(b.getUsagePercentage())
                .period(b.getPeriod().name())
                .startDate(b.getStartDate())
                .endDate(b.getEndDate())
                .alertThresholdPct(b.getAlertThresholdPct())
                .isActive(b.getIsActive())
                .createdAt(b.getCreatedAt())
                .build();
    }
}
