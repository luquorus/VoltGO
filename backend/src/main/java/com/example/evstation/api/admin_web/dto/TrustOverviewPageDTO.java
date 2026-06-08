package com.example.evstation.api.admin_web.dto;

import com.example.evstation.common.web.PaginationResponse;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrustOverviewPageDTO {
    private List<TrustOverviewDTO> content;
    private int page;
    private int size;
    private long totalElements;
    private int totalPages;
    private boolean first;
    private boolean last;

    public static TrustOverviewPageDTO fromPage(PaginationResponse<TrustOverviewDTO> page) {
        return TrustOverviewPageDTO.builder()
                .content(page.getContent())
                .page(page.getPage())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .first(page.isFirst())
                .last(page.isLast())
                .build();
    }
}
