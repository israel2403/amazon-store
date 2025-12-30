import { Kafka, logLevel } from "kafkajs";
import { env, kafkaBrokers } from "../config/env.js";
import { config } from "../config/index.js";
import type { OrderCreatedEvent } from "../types/events.js";

const kafka = new Kafka({
  clientId: env.KAFKA_CLIENT_ID,
  brokers: kafkaBrokers,
  logLevel: config.logging.level === "debug" ? logLevel.DEBUG : logLevel.WARN,
  retry: {
    initialRetryTime: config.kafka.retry.initialRetryTime,
    retries: config.kafka.retry.retries,
  },
  requestTimeout: config.kafka.requestTimeout,
});

export async function startConsumers(): Promise<void> {
  const consumer = kafka.consumer({ 
    groupId: env.KAFKA_GROUP_ID,
    sessionTimeout: config.kafka.sessionTimeout,
  });

  await consumer.connect();
  await consumer.subscribe({ topic: env.KAFKA_TOPIC_ORDER_CREATED, fromBeginning: false });

  await consumer.run({
    autoCommit: true,
    eachMessage: async ({ topic, message }) => {
      const value = message.value?.toString("utf-8");
      if (!value) return;

      // NOTE: later we’ll add validation + idempotency + retries/DLQ
      let evt: OrderCreatedEvent;
      try {
        evt = JSON.parse(value) as OrderCreatedEvent;
      } catch {
        console.error("Invalid JSON message", { topic, value });
        return;
      }

      console.log("Received order.created", {
        eventId: evt.eventId,
        orderId: evt.orderId,
        userId: evt.userId
      });

      // TODO: send email / push notification, etc.
    }
  });

  const shutdown = async () => {
    try {
      await consumer.disconnect();
    } finally {
      process.exit(0);
    }
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}
