package com.financetracker.notificationservice.service;

import com.financetracker.notificationservice.model.SlackIntegration;
import com.financetracker.notificationservice.repository.SlackIntegrationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SlackIntegrationService {

    private final SlackIntegrationRepository slackIntegrationRepository;

    /**
     * Returns the Slack DM channel ID for a given app user ID.
     * Returns null if the user has not connected Slack.
     */
    public String getSlackChannelId(String userId) {
        return slackIntegrationRepository
                .findByUserIdAndIsActiveTrue(UUID.fromString(userId))
                .map(SlackIntegration::getSlackChannelId)
                .orElse(null);
    }

    @Transactional
    public SlackIntegration saveIntegration(UUID userId, String slackUserId,
                                             String teamId, String channelId) {
        Optional<SlackIntegration> existing = slackIntegrationRepository
                .findByUserIdAndIsActiveTrue(userId);

        SlackIntegration integration = existing.orElseGet(() -> SlackIntegration.builder()
                .userId(userId)
                .build());

        integration.setSlackUserId(slackUserId);
        integration.setSlackTeamId(teamId);
        integration.setSlackChannelId(channelId);
        integration.setIsActive(true);

        return slackIntegrationRepository.save(integration);
    }

    @Transactional
    public void disconnectIntegration(UUID userId) {
        slackIntegrationRepository.findByUserIdAndIsActiveTrue(userId)
                .ifPresent(i -> {
                    i.setIsActive(false);
                    slackIntegrationRepository.save(i);
                });
    }
}
