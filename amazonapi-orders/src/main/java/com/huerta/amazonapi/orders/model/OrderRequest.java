package com.huerta.amazonapi.orders.model;

import java.math.BigDecimal;

public record OrderRequest(
		String customerEmail,
		String description,
		BigDecimal totalAmount,
		String status
) {
}
