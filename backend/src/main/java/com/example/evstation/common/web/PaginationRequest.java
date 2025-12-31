package com.example.evstation.common.web;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

@Data
public class PaginationRequest {
    @Min(0)
    private int page = 0;

    @Min(1)
    @Max(100)
    private int size = 20;
    
    private String sortBy = "createdAt";
    private Sort.Direction sortDirection = Sort.Direction.DESC;

    public Pageable toPageable() {
        return PageRequest.of(page, size, sortDirection, sortBy);
    }
}

