package com.example.evstation.common.error;

import com.fasterxml.jackson.core.JsonParseException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> handleHttpMessageNotReadableException(
            HttpMessageNotReadableException ex,
            HttpServletRequest request) {
        String traceId = (String) request.getAttribute("traceId");
        
        String message = "Invalid request body format";
        Map<String, Object> details = new HashMap<>();
        
        if (ex.getCause() instanceof JsonParseException) {
            JsonParseException jsonEx = (JsonParseException) ex.getCause();
            message = "JSON parse error: " + jsonEx.getOriginalMessage();
            
            // Extract location info if available
            if (jsonEx.getLocation() != null) {
                details.put("line", jsonEx.getLocation().getLineNr());
                details.put("column", jsonEx.getLocation().getColumnNr());
            }
            
            // Common JSON errors
            String originalMsg = jsonEx.getOriginalMessage();
            if (originalMsg != null) {
                if (originalMsg.contains("Unexpected character") && originalMsg.contains("}")) {
                    details.put("hint", "Check for extra closing brace '}' or trailing comma before '}'");
                } else if (originalMsg.contains("was expecting double-quote")) {
                    details.put("hint", "Check for missing quotes around field names or unescaped special characters");
                } else if (originalMsg.contains("Unexpected character") && originalMsg.contains(",")) {
                    details.put("hint", "Check for trailing comma ',' before closing brace or bracket");
                }
            }
        } else if (ex.getMessage() != null) {
            message = "Invalid request body: " + ex.getMessage();
        }
        
        log.warn("Invalid request body: traceId={}, error={}, details={}", traceId, message, details);

        ApiError error = ApiError.builder()
                .traceId(traceId)
                .code(ErrorCode.VALIDATION_ERROR.getCode())
                .message(message)
                .details(details.isEmpty() ? null : details)
                .timestamp(Instant.now())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGenericException(
            Exception ex,
            HttpServletRequest request) {
        String traceId = (String) request.getAttribute("traceId");
        
        // Log đầy đủ exception để debug
        log.error("Unhandled exception: traceId={}, message={}, type={}", 
                traceId, ex.getMessage(), ex.getClass().getName(), ex);
        
        // Trả về message rõ ràng hơn (không expose stack trace nhưng có exception message)
        String errorMessage = ex.getMessage() != null && !ex.getMessage().isEmpty() 
                ? ex.getMessage() 
                : ErrorCode.INTERNAL_ERROR.getMessage();
        
        // Nếu là database error, cung cấp hint
        Map<String, Object> details = new HashMap<>();
        if (ex.getClass().getName().contains("SQL") || 
            ex.getClass().getName().contains("DataAccess") ||
            ex.getMessage() != null && ex.getMessage().contains("SQL")) {
            details.put("hint", "Database error. Check database connection and query syntax.");
            errorMessage = "Database error: " + (ex.getCause() != null ? ex.getCause().getMessage() : errorMessage);
        }

        ApiError error = ApiError.builder()
                .traceId(traceId)
                .code(ErrorCode.INTERNAL_ERROR.getCode())
                .message(errorMessage)
                .details(details.isEmpty() ? null : details)
                .timestamp(Instant.now())
                .build();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidationException(
            MethodArgumentNotValidException ex,
            HttpServletRequest request) {
        String traceId = (String) request.getAttribute("traceId");

        Map<String, Object> details = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
                details.put(error.getField(), error.getDefaultMessage())
        );

        ApiError error = ApiError.builder()
                .traceId(traceId)
                .code(ErrorCode.VALIDATION_ERROR.getCode())
                .message(ErrorCode.VALIDATION_ERROR.getMessage())
                .details(details)
                .timestamp(Instant.now())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiError> handleConstraintViolationException(
            ConstraintViolationException ex,
            HttpServletRequest request) {
        String traceId = (String) request.getAttribute("traceId");

        Map<String, Object> details = ex.getConstraintViolations().stream()
                .collect(Collectors.toMap(
                        violation -> violation.getPropertyPath().toString(),
                        violation -> violation.getMessage()
                ));

        ApiError error = ApiError.builder()
                .traceId(traceId)
                .code(ErrorCode.VALIDATION_ERROR.getCode())
                .message(ErrorCode.VALIDATION_ERROR.getMessage())
                .details(details)
                .timestamp(Instant.now())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDeniedException(
            AccessDeniedException ex,
            HttpServletRequest request) {
        String traceId = (String) request.getAttribute("traceId");
        
        log.warn("Access denied: traceId={}, path={}, message={}", 
                traceId, request.getRequestURI(), ex.getMessage());

        ApiError error = ApiError.builder()
                .traceId(traceId)
                .code(ErrorCode.FORBIDDEN.getCode())
                .message("Access denied: " + ex.getMessage())
                .timestamp(Instant.now())
                .build();

        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiError> handleBusinessException(
            BusinessException ex,
            HttpServletRequest request) {
        String traceId = (String) request.getAttribute("traceId");
        
        log.warn("Business exception: traceId={}, code={}, message={}", 
                traceId, ex.getErrorCode().getCode(), ex.getMessage());

        HttpStatus status = switch (ex.getErrorCode()) {
            case NOT_FOUND -> HttpStatus.NOT_FOUND;
            case VALIDATION_ERROR -> HttpStatus.BAD_REQUEST;
            case FORBIDDEN -> HttpStatus.FORBIDDEN;
            case UNAUTHORIZED -> HttpStatus.UNAUTHORIZED;
            default -> HttpStatus.INTERNAL_SERVER_ERROR;
        };

        ApiError error = ApiError.builder()
                .traceId(traceId)
                .code(ex.getErrorCode().getCode())
                .message(ex.getMessage())
                .timestamp(Instant.now())
                .build();

        return ResponseEntity.status(status).body(error);
    }
}

