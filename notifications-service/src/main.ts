import { createServer } from "./api/server.js";
import { env } from "./config/env.js";
import { config } from "./config/index.js";
import { startConsumers } from "./kafka/consumer.js";

async function main() {
  console.log(`Starting ${config.app.name} in ${config.app.environment} mode`);
  console.log(`Log level: ${config.logging.level}`);
  
  // Start Kafka consumers first (or in parallel, your choice)
  startConsumers().catch((err) => {
    console.error("Kafka consumer failed to start", err);
    process.exit(1);
  });

  const app = createServer();
  app.listen(env.APP_PORT, () => {
    console.log(`${config.app.name} listening on port ${env.APP_PORT}`);
  });
}

main().catch((err) => {
  console.error("Fatal error", err);
  process.exit(1);
});
