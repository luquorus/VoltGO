package com.example.evstation.verification.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChecklistAnswer {
    private String itemId;
    private String question;
    private String type;
    private String sourceCode;
    private ChecklistAnswerValue answer;
    private String supplementaryNote;
}
