package com.example.evstation.collaborator.api.dto;

import lombok.Data;

import java.time.LocalDate;

@Data
public class UpdateContractDTO {
    private String region;
    private LocalDate startDate;
    private LocalDate endDate;
    private String note;
}

