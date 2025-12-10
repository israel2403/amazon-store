package com.huerta.amazonapi.orders.service;

import com.huerta.amazonapi.orders.model.Order;
import com.huerta.amazonapi.orders.model.OrderRequest;
import com.huerta.amazonapi.orders.repository.OrderRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderServiceImplTest {

	@Mock
	private OrderRepository orderRepository;

	@InjectMocks
	private OrderServiceImpl orderService;

	private UUID testOrderId;
	private OrderRequest testRequest;

	@BeforeEach
	void setUp() {
		testOrderId = UUID.randomUUID();
		testRequest = new OrderRequest(
				"updated@example.com",
				"Updated description",
				new BigDecimal("150.00"),
				"COMPLETED"
		);
	}

	@Test
	void update_shouldReturnEmptyMonoWhenOrderDoesNotExist() {
		// Given
		UUID nonExistentId = UUID.randomUUID();
		when(orderRepository.findById(nonExistentId)).thenReturn(Mono.empty());

		// When
		Mono<Order> result = orderService.update(nonExistentId, testRequest);

		// Then
		StepVerifier.create(result)
				.verifyComplete();
	}

	@Test
	void update_shouldNotThrowExceptionWhenUpdatingNonExistentOrder() {
		// Given
		UUID nonExistentId = UUID.randomUUID();
		when(orderRepository.findById(nonExistentId)).thenReturn(Mono.empty());

		// When
		Mono<Order> result = orderService.update(nonExistentId, testRequest);

		// Then - should complete without errors
		StepVerifier.create(result)
				.expectNextCount(0)
				.verifyComplete();
	}
}
