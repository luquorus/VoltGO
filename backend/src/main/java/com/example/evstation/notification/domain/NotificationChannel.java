package com.example.evstation.notification.domain;

/**
 * Delivery channel for notifications.
 */
public enum NotificationChannel {
    PUSH,    // Firebase Cloud Messaging
    EMAIL,   // SMTP email
    IN_APP,  // In-app notification stored in DB
}
