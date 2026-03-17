package com.financetracker.transactionservice.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.financetracker.transactionservice.dto.TransactionRequest;
import com.financetracker.transactionservice.dto.TransactionResponse;
import com.financetracker.transactionservice.exception.ResourceNotFoundException;
import com.financetracker.transactionservice.model.Transaction;
import com.financetracker.transactionservice.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final S3Client s3Client;
    private final SqsClient sqsClient;
    private final RedisTemplate<String, String> redisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${aws.s3.bucket}")
    private String s3Bucket;

    @Value("${aws.sqs.budget-alert-queue}")
    private String budgetAlertQueue;

    @Value("${fraud.velocity-check-window-minutes:60}")
    private long velocityWindowMinutes;

    @Value("${fraud.velocity-max-transactions:20}")
    private long velocityMaxTransactions;

    @Value("${fraud.large-transaction-threshold:5000.00}")
    private BigDecimal largeTxThreshold;

    @Transactional
    public TransactionResponse create(UUID userId, TransactionRequest request, MultipartFile receipt) {
        // Fraud detection: velocity check via Redis counter
        performVelocityCheck(userId);

        Transaction transaction = Transaction.builder()
                .userId(userId)
                .categoryId(request.getCategoryId())
                .type(Transaction.TransactionType.valueOf(request.getType()))
                .amount(request.getAmount())
                .currency(request.getCurrency() != null ? request.getCurrency() : "USD")
                .description(request.getDescription())
                .merchant(request.getMerchant())
                .transactionDate(request.getTransactionDate() != null
                        ? request.getTransactionDate() : java.time.LocalDate.now())
                .isRecurring(request.getIsRecurring() != null && request.getIsRecurring())
                .location(request.getLocation())
                .notes(request.getNotes())
                .isFlagged(request.getAmount().compareTo(largeTxThreshold) > 0)
                .build();

        // Upload receipt to S3 if provided
        if (receipt != null && !receipt.isEmpty()) {
            String receiptUrl = uploadReceiptToS3(userId, receipt);
            transaction.setReceiptUrl(receiptUrl);
        }

        Transaction saved = transactionRepository.save(transaction);
        log.info("Transaction created: {} for user {}", saved.getId(), userId);

        // Publish budget alert event asynchronously via SQS
        publishBudgetAlertEvent(saved);

        return mapToResponse(saved);
    }

    public Page<TransactionResponse> getAll(UUID userId, Pageable pageable) {
        return transactionRepository
                .findByUserIdOrderByTransactionDateDesc(userId, pageable)
                .map(this::mapToResponse);
    }

    public TransactionResponse getById(UUID userId, UUID transactionId) {
        Transaction tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        if (!tx.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Transaction not found");
        }
        return mapToResponse(tx);
    }

    @Transactional
    public TransactionResponse update(UUID userId, UUID transactionId, TransactionRequest request) {
        Transaction tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        if (!tx.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Transaction not found");
        }

        tx.setCategoryId(request.getCategoryId());
        tx.setAmount(request.getAmount());
        tx.setDescription(request.getDescription());
        tx.setMerchant(request.getMerchant());
        tx.setNotes(request.getNotes());
        if (request.getTransactionDate() != null) {
            tx.setTransactionDate(request.getTransactionDate());
        }

        return mapToResponse(transactionRepository.save(tx));
    }

    @Transactional
    public void delete(UUID userId, UUID transactionId) {
        Transaction tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        if (!tx.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Transaction not found");
        }
        transactionRepository.delete(tx);
        log.info("Transaction deleted: {} by user {}", transactionId, userId);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private void performVelocityCheck(UUID userId) {
        String velocityKey = "velocity:" + userId;
        Long count = redisTemplate.opsForValue().increment(velocityKey);
        if (count == 1) {
            redisTemplate.expire(velocityKey, velocityWindowMinutes, TimeUnit.MINUTES);
        }
        if (count != null && count > velocityMaxTransactions) {
            log.warn("Velocity check triggered for user {}: {} transactions in {}min",
                    userId, count, velocityWindowMinutes);
            // Flag but don't block — alert service will review
        }
    }

    private String uploadReceiptToS3(UUID userId, MultipartFile file) {
        String key = String.format("receipts/%s/%s-%s",
                userId,
                UUID.randomUUID(),
                sanitizeFilename(Objects.requireNonNull(file.getOriginalFilename())));
        try {
            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(s3Bucket)
                    .key(key)
                    .contentType(file.getContentType())
                    .contentLength(file.getSize())
                    .build();
            s3Client.putObject(putRequest, RequestBody.fromBytes(file.getBytes()));
            return "s3://" + s3Bucket + "/" + key;
        } catch (IOException e) {
            log.error("Failed to upload receipt to S3: {}", e.getMessage());
            throw new RuntimeException("Receipt upload failed", e);
        }
    }

    private void publishBudgetAlertEvent(Transaction tx) {
        try {
            Map<String, Object> event = new HashMap<>();
            event.put("eventType", "TRANSACTION_CREATED");
            event.put("transactionId", tx.getId().toString());
            event.put("userId", tx.getUserId().toString());
            event.put("categoryId", tx.getCategoryId() != null ? tx.getCategoryId().toString() : null);
            event.put("amount", tx.getAmount());
            event.put("type", tx.getType().name());
            event.put("transactionDate", tx.getTransactionDate().toString());

            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(budgetAlertQueue)
                    .messageBody(objectMapper.writeValueAsString(event))
                    .build());
        } catch (Exception e) {
            // Non-critical: log and continue (SQS is async)
            log.error("Failed to publish budget alert event: {}", e.getMessage());
        }
    }

    /**
     * Prevents path traversal in S3 keys by removing dangerous characters.
     */
    private String sanitizeFilename(String filename) {
        return filename.replaceAll("[^a-zA-Z0-9._-]", "_");
    }

    private TransactionResponse mapToResponse(Transaction tx) {
        return TransactionResponse.builder()
                .id(tx.getId())
                .userId(tx.getUserId())
                .categoryId(tx.getCategoryId())
                .type(tx.getType().name())
                .amount(tx.getAmount())
                .currency(tx.getCurrency())
                .description(tx.getDescription())
                .merchant(tx.getMerchant())
                .receiptUrl(tx.getReceiptUrl())
                .transactionDate(tx.getTransactionDate())
                .isFlagged(tx.getIsFlagged())
                .createdAt(tx.getCreatedAt())
                .build();
    }
}
package com.financetracker.transactionservice.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.financetracker.transactionservice.dto.TransactionRequest;
import com.financetracker.transactionservice.dto.TransactionResponse;
import com.financetracker.transactionservice.exception.ResourceNotFoundException;
import com.financetracker.transactionservice.model.Transaction;
import com.financetracker.transactionservice.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final S3Client s3Client;
    private final SqsClient sqsClient;
    private final RedisTemplate<String, String> redisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${aws.s3.bucket}")
    private String s3Bucket;

    @Value("${aws.sqs.budget-alert-queue}")
    private String budgetAlertQueue;

    @Value("${fraud.velocity-check-window-minutes:60}")
    private long velocityWindowMinutes;

    @Value("${fraud.velocity-max-transactions:20}")
    private long velocityMaxTransactions;

    @Value("${fraud.large-transaction-threshold:5000.00}")
    private BigDecimal largeTxThreshold;

    @Transactional
    public TransactionResponse create(UUID userId, TransactionRequest request, MultipartFile receipt) {
        // Fraud detection: velocity check via Redis counter
        performVelocityCheck(userId);

        Transaction transaction = Transaction.builder()
                .userId(userId)
                .categoryId(request.getCategoryId())
                .type(Transaction.TransactionType.valueOf(request.getType()))
                .amount(request.getAmount())
                .currency(request.getCurrency() != null ? request.getCurrency() : "USD")
                .description(request.getDescription())
                .merchant(request.getMerchant())
                .transactionDate(request.getTransactionDate() != null
                        ? request.getTransactionDate() : java.time.LocalDate.now())
                .isRecurring(request.getIsRecurring() != null && request.getIsRecurring())
                .location(request.getLocation())
                .notes(request.getNotes())
                .isFlagged(request.getAmount().compareTo(largeTxThreshold) > 0)
                .build();

        // Upload receipt to S3 if provided
        if (receipt != null && !receipt.isEmpty()) {
            String receiptUrl = uploadReceiptToS3(userId, receipt);
            transaction.setReceiptUrl(receiptUrl);
        }

        Transaction saved = transactionRepository.save(transaction);
        log.info("Transaction created: {} for user {}", saved.getId(), userId);

        // Publish budget alert event asynchronously via SQS
        publishBudgetAlertEvent(saved);

        return mapToResponse(saved);
    }

    public Page<TransactionResponse> getAll(UUID userId, Pageable pageable) {
        return transactionRepository
                .findByUserIdOrderByTransactionDateDesc(userId, pageable)
                .map(this::mapToResponse);
    }

    public TransactionResponse getById(UUID userId, UUID transactionId) {
        Transaction tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        if (!tx.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Transaction not found");
        }
        return mapToResponse(tx);
    }

    @Transactional
    public TransactionResponse update(UUID userId, UUID transactionId, TransactionRequest request) {
        Transaction tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        if (!tx.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Transaction not found");
        }

        tx.setCategoryId(request.getCategoryId());
        tx.setAmount(request.getAmount());
        tx.setDescription(request.getDescription());
        tx.setMerchant(request.getMerchant());
        tx.setNotes(request.getNotes());
        if (request.getTransactionDate() != null) {
            tx.setTransactionDate(request.getTransactionDate());
        }

        return mapToResponse(transactionRepository.save(tx));
    }

    @Transactional
    public void delete(UUID userId, UUID transactionId) {
        Transaction tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        if (!tx.getUserId().equals(userId)) {
            throw new ResourceNotFoundException("Transaction not found");
        }
        transactionRepository.delete(tx);
        log.info("Transaction deleted: {} by user {}", transactionId, userId);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private void performVelocityCheck(UUID userId) {
        String velocityKey = "velocity:" + userId;
        Long count = redisTemplate.opsForValue().increment(velocityKey);
        if (count == 1) {
            redisTemplate.expire(velocityKey, velocityWindowMinutes, TimeUnit.MINUTES);
        }
        if (count != null && count > velocityMaxTransactions) {
            log.warn("Velocity check triggered for user {}: {} transactions in {}min",
                    userId, count, velocityWindowMinutes);
            // Flag but don't block — alert service will review
        }
    }

    private String uploadReceiptToS3(UUID userId, MultipartFile file) {
        String key = String.format("receipts/%s/%s-%s",
                userId,
                UUID.randomUUID(),
                sanitizeFilename(Objects.requireNonNull(file.getOriginalFilename())));
        try {
            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(s3Bucket)
                    .key(key)
                    .contentType(file.getContentType())
                    .contentLength(file.getSize())
                    .build();
            s3Client.putObject(putRequest, RequestBody.fromBytes(file.getBytes()));
            return "s3://" + s3Bucket + "/" + key;
        } catch (IOException e) {
            log.error("Failed to upload receipt to S3: {}", e.getMessage());
            throw new RuntimeException("Receipt upload failed", e);
        }
    }

    private void publishBudgetAlertEvent(Transaction tx) {
        try {
            Map<String, Object> event = new HashMap<>();
            event.put("eventType", "TRANSACTION_CREATED");
            event.put("transactionId", tx.getId().toString());
            event.put("userId", tx.getUserId().toString());
            event.put("categoryId", tx.getCategoryId() != null ? tx.getCategoryId().toString() : null);
            event.put("amount", tx.getAmount());
            event.put("type", tx.getType().name());
            event.put("transactionDate", tx.getTransactionDate().toString());

            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(budgetAlertQueue)
                    .messageBody(objectMapper.writeValueAsString(event))
                    .build());
        } catch (Exception e) {
            // Non-critical: log and continue (SQS is async)
            log.error("Failed to publish budget alert event: {}", e.getMessage());
        }
    }

    /**
     * Prevents path traversal in S3 keys by removing dangerous characters.
     */
    private String sanitizeFilename(String filename) {
        return filename.replaceAll("[^a-zA-Z0-9._-]", "_");
    }

    private TransactionResponse mapToResponse(Transaction tx) {
        return TransactionResponse.builder()
                .id(tx.getId())
                .userId(tx.getUserId())
                .categoryId(tx.getCategoryId())
                .type(tx.getType().name())
                .amount(tx.getAmount())
                .currency(tx.getCurrency())
                .description(tx.getDescription())
                .merchant(tx.getMerchant())
                .receiptUrl(tx.getReceiptUrl())
                .transactionDate(tx.getTransactionDate())
                .isFlagged(tx.getIsFlagged())
                .createdAt(tx.getCreatedAt())
                .build();
    }
}
