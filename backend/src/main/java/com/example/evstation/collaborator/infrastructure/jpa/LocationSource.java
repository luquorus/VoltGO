package com.example.evstation.collaborator.infrastructure.jpa;

/**
 * Source of collaborator location update.
 */
public enum LocationSource {
    /**
     * Location updated from mobile device GPS
     */
    MOBILE,
    
    /**
     * Location updated manually from web interface
     */
    WEB
}

