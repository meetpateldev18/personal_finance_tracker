package com.financetracker.notificationservice.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.GenericGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "slack_integrations")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SlackIntegration {

    @Id
    @GeneratedValue(generator = "uuid2")
    @GenericGenerator(name = "uuid2", strategy = "uuid2")
    @Column(columnDefinition = "UUID", updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, unique = true)
    private UUID userId;

    @Column(name = "slack_user_id")
    private String slackUserId;

    @Column(name = "slack_team_id")
    private String slackTeamId;

    @Column(name = "slack_channel_id")
    private String slackChannelId;

    @Column(name = "access_token")
    private String accessToken;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "connected_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant connectedAt = Instant.now();

    @Column(name = "updated_at")
    @Builder.Default
    private Instant updatedAt = Instant.now();

    @PreUpdate
    public void preUpdate() { this.updatedAt = Instant.now(); }
}
