import "dotenv/config";
import { z } from "zod";

const EnvSchema = z.object({
  APP_PORT: z.coerce.number().int().positive().default(3000),

  KAFKA_BROKERS: z.string().min(1), // comma-separated
  KAFKA_CLIENT_ID: z.string().min(1),
  KAFKA_GROUP_ID: z.string().min(1),
  KAFKA_TOPIC_ORDER_CREATED: z.string().min(1)
});

export type AppEnv = z.infer<typeof EnvSchema>;

export const env: AppEnv = EnvSchema.parse(process.env);

export const kafkaBrokers = env.KAFKA_BROKERS.split(",").map(s => s.trim()).filter(Boolean);
