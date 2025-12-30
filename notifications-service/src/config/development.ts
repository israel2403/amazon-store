export const developmentConfig = {
  app: {
    name: "notifications-service",
    environment: "development",
  },
  
  logging: {
    level: "debug",
    prettyPrint: true,
  },
  
  kafka: {
    retry: {
      initialRetryTime: 300,
      retries: 8,
    },
    requestTimeout: 30000,
    sessionTimeout: 30000,
  },
  
  server: {
    requestTimeout: 30000,
    keepAliveTimeout: 65000,
  },
};
