import { useState } from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import KRGlue from '@lyracom/embedded-form-glue';
import PayzenAPI from '../../../app/frontend/src/javascript/api/payzen';
import SettingAPI from '../../../app/frontend/src/javascript/api/setting';
import { PayzenForm } from '../../../app/frontend/src/javascript/components/payment/payzen/payzen-form';
import { ShoppingCart } from '../../../app/frontend/src/javascript/models/payment';
import { User } from '../../../app/frontend/src/javascript/models/user';

jest.mock('@lyracom/embedded-form-glue', () => ({ loadLibrary: jest.fn() }));

const customer = { id: 1 } as User;
const cart = { customer_id: customer.id } as ShoppingCart;

afterEach(() => jest.restoreAllMocks());

async function mountPayzenForm () {
  const checkCart = jest.spyOn(PayzenAPI, 'checkCart').mockResolvedValue({ formToken: 'token', orderId: 'order' });
  jest.spyOn(PayzenAPI, 'chargeCreatePayment').mockResolvedValue({ formToken: 'token', orderId: 'order' });
  jest.spyOn(SettingAPI, 'query').mockResolvedValue(new Map());

  const client = {
    setFormConfig: jest.fn(() => Promise.resolve({ KR: client })),
    addForm: jest.fn(() => Promise.resolve({ KR: client, result: { formId: 'payzen' } })),
    showForm: jest.fn(() => Promise.resolve({ KR: client })),
    onFormReady: jest.fn(() => Promise.resolve({ KR: client })),
    onFormCreated: jest.fn(() => Promise.resolve({ KR: client })),
    onSubmit: jest.fn(),
    onError: jest.fn(),
    submit: jest.fn(),
    validateForm: jest.fn()
  };
  jest.mocked(KRGlue.loadLibrary).mockResolvedValue({ KR: client });
  client.validateForm.mockResolvedValue({ KR: client, result: null });

  const onError = jest.fn();
  function Checkout () {
    const [submitting, setSubmitting] = useState(false);
    return <PayzenForm formId="payzen-test"
      cart={cart}
      customer={customer}
      operator={customer}
      onSubmit={() => setSubmitting(true)}
      onSuccess={jest.fn()}
      onError={(errorMessage) => {
        onError(errorMessage);
        setSubmitting(false);
      }}>
      <button type="submit" disabled={submitting}>Pay</button>
    </PayzenForm>;
  }

  render(<Checkout />);
  await waitFor(() => expect(client.onFormCreated).toHaveBeenCalled());
  return { checkCart, client, onError, pay: screen.getByRole('button', { name: 'Pay' }) };
}

test.each([
  [{ errorMessage: 'Check the card details', detailedErrorMessage: 'Enter the security code' }, 'Check the card details. Enter the security code'],
  [null, 'app.shared.payzen_form.unexpected_error']
])('makes a PayZen validation failure (%j) visible and allows correction', async (result, message) => {
  const { checkCart, client, onError, pay } = await mountPayzenForm();
  client.validateForm.mockRejectedValueOnce({ KR: client, result });

  fireEvent.click(pay);
  await waitFor(() => expect(onError).toHaveBeenCalledWith(message));
  expect(pay).toBeEnabled();
  expect(checkCart).not.toHaveBeenCalled();
  expect(client.submit).not.toHaveBeenCalled();

  fireEvent.click(pay);
  await waitFor(() => expect(client.submit).toHaveBeenCalledTimes(1));
  expect(checkCart).toHaveBeenCalledTimes(1);
});

test('keeps the cart validation message and stops payment submission', async () => {
  const { checkCart, client, onError, pay } = await mountPayzenForm();
  const message = 'This reservation slot is no longer available.';
  checkCart.mockRejectedValueOnce(message);

  fireEvent.click(pay);
  await waitFor(() => expect(onError).toHaveBeenCalledWith(message));
  expect(pay).toBeEnabled();
  expect(client.submit).not.toHaveBeenCalled();
});
