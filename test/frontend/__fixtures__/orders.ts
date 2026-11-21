import { Order } from '../../../app/frontend/src/javascript/models/order';

const orders: Array<Order> = [
  {
    id: 1,
    token: 'wallet-paid-order',
    reference: '000001',
    state: 'paid',
    total: 50,
    paid_total: 0,
    wallet_amount: 40,
    created_at: '2022-12-05T16:15:00Z',
    updated_at: '2022-12-05T16:15:00Z',
    order_items_attributes: []
  }
];

export default orders;
