package com.example.evstation.station.domain;

/**
 * Status of a reported issue.
 */
public enum IssueStatus {
    OPEN,           // New issue, not yet reviewed
    ACKNOWLEDGED,   // Admin has seen and is investigating
    RESOLVED,       // Issue has been fixed
    REJECTED        // Issue was invalid or not actionable
}

