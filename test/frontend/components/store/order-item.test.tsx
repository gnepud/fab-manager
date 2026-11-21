import { render } from '@testing-library/react';
import '@testing-library/jest-dom';
import { OrderItem } from '../../../../app/frontend/src/javascript/components/store/order-item';
import FormatLib from '../../../../app/frontend/src/javascript/lib/format';
import orders from '../../__fixtures__/orders';

describe('OrderItem', () => {
  test.each([
    ['fully wallet-paid', { paid_total: 0, wallet_amount: 40 }, 40],
    ['mixed payment', { paid_total: 25.25, wallet_amount: 14.75 }, 40],
    ['without wallet payment', { paid_total: 40, wallet_amount: undefined }, 40],
    ['zero wallet payment', { paid_total: 40, wallet_amount: 0 }, 40],
    ['free order', { paid_total: 0, wallet_amount: undefined }, 0]
  ])('shows the full total for a %s order', (_name, payment, expected) => {
    const { container } = render(<OrderItem order={{ ...orders[0], ...payment }} />);
    expect(container.querySelector('.price p').textContent).toBe(FormatLib.price(expected));
  });

  test('keeps the cart total', () => {
    const { container } = render(<OrderItem order={{ ...orders[0], state: 'cart' }} />);
    expect(container.querySelector('.price p').textContent).toBe(FormatLib.price(50));
  });
});
