import { developmentConfig } from "./development.js";
import { productionConfig } from "./production.js";

type Config = typeof developmentConfig;

export function loadConfig(): Config {
  const nodeEnv = process.env.NODE_ENV || "development";
  
  switch (nodeEnv) {
    case "production":
      return productionConfig;
    case "development":
    default:
      return developmentConfig;
  }
}

export const config = loadConfig();
