package com.huerta.amazonapi.orders.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import java.util.UUID;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.huerta.amazonapi.orders.model.Order;
import com.huerta.amazonapi.orders.model.OrderRequest;
import com.huerta.amazonapi.orders.service.OrderService;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

	private final OrderService orderService;

	public OrderController(OrderService orderService) {
		this.orderService = orderService;
	}

	@GetMapping
	public Flux<Order> getOrders() {
		return orderService.getAll();
	}

	@GetMapping("/{id}")
	public Mono<ResponseEntity<Order>> getOrder(@PathVariable UUID id) {
		return orderService.getById(id)
				.map(ResponseEntity::ok)
				.defaultIfEmpty(ResponseEntity.notFound().build());
	}

	@PostMapping
	public Mono<ResponseEntity<Order>> createOrder(@RequestBody OrderRequest request) {
		return orderService.create(request)
				.map(saved -> ResponseEntity.status(HttpStatus.CREATED).body(saved));
	}

	@PutMapping("/{id}")
	public Mono<ResponseEntity<Order>> updateOrder(@PathVariable UUID id, @RequestBody OrderRequest request) {
		return orderService.update(id, request)
				.map(ResponseEntity::ok)
				.defaultIfEmpty(ResponseEntity.notFound().build());
	}

	@DeleteMapping("/{id}")
	public Mono<ResponseEntity<Void>> deleteOrder(@PathVariable UUID id) {
		return orderService.delete(id)
				.map(deleted -> deleted
						? ResponseEntity.noContent().build()
						: ResponseEntity.notFound().build());
	}
}
