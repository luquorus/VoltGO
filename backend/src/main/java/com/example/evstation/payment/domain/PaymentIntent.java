package com.example.evstation.payment.domain;

import java.time.Instant;
import java.util.UUID;

/**
 * Domain entity for PaymentIntent
 * Represents a payment intent for a booking
 */
public class PaymentIntent {
    
    private final UUID id;
    private final UUID bookingId;
    private final int amount;
    private final String currency;
    private final PaymentIntentStatus status;
    private final Instant createdAt;
    private final Instant updatedAt;
    
    private PaymentIntent(Builder builder) {
        this.id = builder.id;
        this.bookingId = builder.bookingId;
        this.amount = builder.amount;
        this.currency = builder.currency;
        this.status = builder.status;
        this.createdAt = builder.createdAt;
        this.updatedAt = builder.updatedAt;
    }
    
    public static Builder builder() {
        return new Builder();
    }
    
    public UUID getId() {
        return id;
    }
    
    public UUID getBookingId() {
        return bookingId;
    }
    
    public int getAmount() {
        return amount;
    }
    
    public String getCurrency() {
        return currency;
    }
    
    public PaymentIntentStatus getStatus() {
        return status;
    }
    
    public Instant getCreatedAt() {
        return createdAt;
    }
    
    public Instant getUpdatedAt() {
        return updatedAt;
    }
    
    /**
     * Check if payment intent can be processed (status is CREATED)
     */
    public boolean canBeProcessed() {
        return status == PaymentIntentStatus.CREATED;
    }
    
    /**
     * Check if payment is successful
     */
    public boolean isSucceeded() {
        return status == PaymentIntentStatus.SUCCEEDED;
    }
    
    public static class Builder {
        private UUID id;
        private UUID bookingId;
        private int amount;
        private String currency = "VND";
        private PaymentIntentStatus status;
        private Instant createdAt;
        private Instant updatedAt;
        
        public Builder id(UUID id) {
            this.id = id;
            return this;
        }
        
        public Builder bookingId(UUID bookingId) {
            this.bookingId = bookingId;
            return this;
        }
        
        public Builder amount(int amount) {
            this.amount = amount;
            return this;
        }
        
        public Builder currency(String currency) {
            this.currency = currency;
            return this;
        }
        
        public Builder status(PaymentIntentStatus status) {
            this.status = status;
            return this;
        }
        
        public Builder createdAt(Instant createdAt) {
            this.createdAt = createdAt;
            return this;
        }
        
        public Builder updatedAt(Instant updatedAt) {
            this.updatedAt = updatedAt;
            return this;
        }
        
        public PaymentIntent build() {
            if (bookingId == null) {
                throw new IllegalArgumentException("bookingId is required");
            }
            if (amount <= 0) {
                throw new IllegalArgumentException("amount must be positive");
            }
            if (currency == null || currency.isEmpty()) {
                throw new IllegalArgumentException("currency is required");
            }
            if (status == null) {
                throw new IllegalArgumentException("status is required");
            }
            if (createdAt == null) {
                throw new IllegalArgumentException("createdAt is required");
            }
            if (updatedAt == null) {
                throw new IllegalArgumentException("updatedAt is required");
            }
            
            return new PaymentIntent(this);
        }
    }
}

