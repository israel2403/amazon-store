package com.huerta.amazonapi.orders.controller;

import com.huerta.amazonapi.orders.model.Order;
import com.huerta.amazonapi.orders.model.OrderRequest;
import com.huerta.amazonapi.orders.service.OrderService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderControllerTest {

	@Mock
	private OrderService orderService;

	@InjectMocks
	private OrderController orderController;

	private Order testOrder;
	private OrderRequest testRequest;

	@BeforeEach
	void setUp() {
		UUID testId = UUID.randomUUID();
		Instant now = Instant.now();

		testOrder = Order.builder()
				.id(testId)
				.customerEmail("test@example.com")
				.description("Test order")
				.totalAmount(new BigDecimal("99.99"))
				.status("PENDING")
				.createdAt(now)
				.updatedAt(now)
				.build();

		testRequest = new OrderRequest(
				"test@example.com",
				"Test order",
				new BigDecimal("99.99"),
				"PENDING"
		);
	}

	@Test
	void create_shouldCreateOrderAndReturnWithCreatedStatus() {
		// Given
		when(orderService.create(any(OrderRequest.class)))
				.thenReturn(Mono.just(testOrder));

		// When
		Mono<ResponseEntity<Order>> result = orderController.createOrder(testRequest);

		// Then
		StepVerifier.create(result)
				.assertNext(response -> {
					assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
					assertThat(response.getBody()).isNotNull();
					assertThat(response.getBody().getId()).isEqualTo(testOrder.getId());
					assertThat(response.getBody().getCustomerEmail()).isEqualTo("test@example.com");
					assertThat(response.getBody().getTotalAmount()).isEqualByComparingTo(new BigDecimal("99.99"));
				})
				.verifyComplete();
	}

	@Test
	void getAll_shouldReturnAllOrders() {
		// Given
		Order order1 = Order.builder()
				.id(UUID.randomUUID())
				.customerEmail("user1@example.com")
				.description("Order 1")
				.totalAmount(new BigDecimal("50.00"))
				.status("PENDING")
				.createdAt(Instant.now())
				.updatedAt(Instant.now())
				.build();

		Order order2 = Order.builder()
				.id(UUID.randomUUID())
				.customerEmail("user2@example.com")
				.description("Order 2")
				.totalAmount(new BigDecimal("75.00"))
				.status("COMPLETED")
				.createdAt(Instant.now())
				.updatedAt(Instant.now())
				.build();

		when(orderService.getAll()).thenReturn(Flux.just(order1, order2));

		// When
		Flux<Order> result = orderController.getOrders();

		// Then
		StepVerifier.create(result)
				.assertNext(order -> {
					assertThat(order.getId()).isEqualTo(order1.getId());
					assertThat(order.getCustomerEmail()).isEqualTo("user1@example.com");
				})
				.assertNext(order -> {
					assertThat(order.getId()).isEqualTo(order2.getId());
					assertThat(order.getCustomerEmail()).isEqualTo("user2@example.com");
				})
				.verifyComplete();
	}

	@Test
	void getAll_shouldReturnEmptyListWhenNoOrdersExist() {
		// Given
		when(orderService.getAll()).thenReturn(Flux.empty());

		// When
		Flux<Order> result = orderController.getOrders();

		// Then
		StepVerifier.create(result)
				.verifyComplete();
	}
}
