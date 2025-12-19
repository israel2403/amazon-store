export type OrderCreatedEvent = {
  eventId: string;
  orderId: string;
  userId: string;
  total: number;
  currency: string;
  createdAt: string; // ISO
};
