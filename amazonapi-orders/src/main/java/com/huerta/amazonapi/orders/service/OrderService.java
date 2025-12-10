package com.huerta.amazonapi.orders.service;

import java.util.UUID;

import com.huerta.amazonapi.orders.model.Order;
import com.huerta.amazonapi.orders.model.OrderRequest;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

public interface OrderService {

	Flux<Order> getAll();

	Mono<Order> getById(UUID id);

	Mono<Order> create(OrderRequest request);

	Mono<Order> update(UUID id, OrderRequest request);

	Mono<Boolean> delete(UUID id);
}
