package com.huerta.amazonapi.orders.service;

import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.huerta.amazonapi.orders.model.Order;
import com.huerta.amazonapi.orders.model.OrderRequest;
import com.huerta.amazonapi.orders.repository.OrderRepository;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Service
public class OrderServiceImpl implements OrderService {

	private final OrderRepository orderRepository;

	public OrderServiceImpl(OrderRepository orderRepository) {
		this.orderRepository = orderRepository;
	}

	@Override
	public Flux<Order> getAll() {
		return orderRepository.findAll();
	}

	@Override
	public Mono<Order> getById(UUID id) {
		return orderRepository.findById(id);
	}

	@Override
	public Mono<Order> create(OrderRequest request) {
		Instant now = Instant.now();
		Order order = new Order(
				null, // Use DB default UUID generation
				request.customerEmail(),
				request.description(),
				request.totalAmount(),
				request.status() != null ? request.status() : "PENDING",
				now,
				now
		);
		return orderRepository.save(order);
	}

	@Override
	public Mono<Order> update(UUID id, OrderRequest request) {
		return orderRepository.findById(id)
				.flatMap(existing -> {
					if (request.customerEmail() != null) {
						existing.setCustomerEmail(request.customerEmail());
					}
					if (request.description() != null) {
						existing.setDescription(request.description());
					}
					if (request.totalAmount() != null) {
						existing.setTotalAmount(request.totalAmount());
					}
					if (request.status() != null) {
						existing.setStatus(request.status());
					}
					existing.setUpdatedAt(Instant.now());
					return orderRepository.save(existing);
				});
	}

	@Override
	public Mono<Boolean> delete(UUID id) {
		return orderRepository.existsById(id)
				.flatMap(exists -> exists
						? orderRepository.deleteById(id).thenReturn(true)
						: Mono.just(false));
	}
}
