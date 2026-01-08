package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.booking.application.BookingResponseDTO;
import com.example.evstation.booking.application.BookingService;
import com.example.evstation.booking.application.CreateBookingDTO;
import com.example.evstation.common.web.PaginationRequest;
import com.example.evstation.common.web.PaginationResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@Tag(name = "Bookings", description = "API for EV Users to manage bookings")
@RestController
@RequestMapping("/api/ev/bookings")
@RequiredArgsConstructor
@PreAuthorize("hasRole('EV_USER')")
public class BookingController {
    
    private final BookingService bookingService;
    
    @Operation(
        summary = "Create a new booking",
        description = "Create a booking with HOLD status. Hold expires in 10 minutes. " +
                      "Station must exist and have a published version."
    )
    @PostMapping
    public ResponseEntity<BookingResponseDTO> createBooking(
            @Valid @RequestBody CreateBookingDTO request,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Creating booking: stationId={}, userId={}", request.getStationId(), userId);
        
        BookingResponseDTO response = bookingService.createBooking(request, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
    
    @Operation(
        summary = "Get my bookings",
        description = "Get all bookings for the current user, paginated"
    )
    @GetMapping("/mine")
    public ResponseEntity<PaginationResponse<BookingResponseDTO>> getMyBookings(
            PaginationRequest pagination,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.debug("Getting bookings for user: {}", userId);
        
        Page<BookingResponseDTO> page = bookingService.getMyBookings(
                userId, pagination.toPageable());
        
        return ResponseEntity.ok(PaginationResponse.fromPage(page));
    }
    
    @Operation(
        summary = "Get booking by ID",
        description = "Get a specific booking by ID (only if it belongs to the current user)"
    )
    @GetMapping("/{id}")
    public ResponseEntity<BookingResponseDTO> getBooking(
            @Parameter(description = "Booking ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.debug("Getting booking: id={}, userId={}", id, userId);
        
        return bookingService.getBooking(id, userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @Operation(
        summary = "Cancel a booking",
        description = "Cancel a booking. Allowed when status is HOLD or CONFIRMED."
    )
    @PostMapping("/{id}/cancel")
    public ResponseEntity<BookingResponseDTO> cancelBooking(
            @Parameter(description = "Booking ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Cancelling booking: id={}, userId={}", id, userId);
        
        BookingResponseDTO response = bookingService.cancelBooking(id, userId);
        return ResponseEntity.ok(response);
    }
    
    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}

