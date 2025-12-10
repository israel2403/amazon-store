package com.huerta.amazonapi.orders.repository;

import java.util.UUID;

import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;

import com.huerta.amazonapi.orders.model.Order;

@Repository
public interface OrderRepository extends ReactiveCrudRepository<Order, UUID> {
}
