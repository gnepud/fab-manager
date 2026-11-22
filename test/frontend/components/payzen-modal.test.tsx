import { useState } from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import CustomAssetAPI from '../../../app/frontend/src/javascript/api/custom-asset';
import PriceAPI from '../../../app/frontend/src/javascript/api/price';
import SettingAPI from '../../../app/frontend/src/javascript/api/setting';
import WalletAPI from '../../../app/frontend/src/javascript/api/wallet';
import { GatewayFormProps } from '../../../app/frontend/src/javascript/components/payment/abstract-payment-modal';
import { PayzenModal } from '../../../app/frontend/src/javascript/components/payment/payzen/payzen-modal';
import { ShoppingCart } from '../../../app/frontend/src/javascript/models/payment';
import { User } from '../../../app/frontend/src/javascript/models/user';
import { Wallet } from '../../../app/frontend/src/javascript/models/wallet';

jest.mock('../../../app/frontend/src/javascript/lib/i18n', () => ({}));

jest.mock('../../../app/frontend/src/javascript/components/payment/payzen/payzen-form', () => ({
  PayzenForm: ({ onSubmit, onError, children }: GatewayFormProps) => <>
    <button onClick={onSubmit}>Start payment</button>
    <button onClick={() => onError('Too many attempts')}>Report gateway error</button>
    {children}
  </>
}));

afterEach(() => jest.restoreAllMocks());

test('allows the customer to close PayZen checkout after retries are exhausted', async () => {
  const customer = { id: 1 } as User;
  const cart = { customer_id: customer.id } as ShoppingCart;
  jest.spyOn(CustomAssetAPI, 'get').mockResolvedValue(null);
  jest.spyOn(SettingAPI, 'get').mockResolvedValue({ name: 'payment_gateway', value: 'payzen' });
  jest.spyOn(WalletAPI, 'getByUser').mockResolvedValue({ amount: 0 } as Wallet);
  jest.spyOn(PriceAPI, 'compute').mockResolvedValue({ price: 12, price_without_coupon: 12 });

  function Checkout () {
    const [open, setOpen] = useState(true);
    return <PayzenModal isOpen={open} toggleModal={() => setOpen(false)}
      cart={cart} currentUser={customer} customer={customer}
      afterSuccess={jest.fn()} onError={jest.fn()} />;
  }

  render(<Checkout />);
  const closeLabel = 'app.shared.fab_modal.close';
  fireEvent.click(await screen.findByText('Start payment'));
  expect(screen.queryByText(closeLabel)).not.toBeInTheDocument();
  fireEvent.click(screen.getByText('Report gateway error'));
  expect(screen.getByText('Too many attempts')).toBeVisible();
  fireEvent.click(screen.getByText(closeLabel, { selector: 'button' }));
  expect(screen.queryByRole('dialog', { hidden: true })).not.toBeInTheDocument();
});
