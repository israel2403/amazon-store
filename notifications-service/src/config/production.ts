export const productionConfig = {
  app: {
    name: "notifications-service",
    environment: "production",
  },
  
  logging: {
    level: "info",
    prettyPrint: false,
  },
  
  kafka: {
    retry: {
      initialRetryTime: 100,
      retries: 10,
    },
    requestTimeout: 60000,
    sessionTimeout: 60000,
  },
  
  server: {
    requestTimeout: 60000,
    keepAliveTimeout: 120000,
  },
};
