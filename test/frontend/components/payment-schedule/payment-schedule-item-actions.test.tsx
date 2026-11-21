import { fireEvent, render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { PaymentScheduleItemActions } from '../../../../app/frontend/src/javascript/components/payment-schedule/payment-schedule-item-actions';
import FormatLib from '../../../../app/frontend/src/javascript/lib/format';
import { PaymentMethod } from '../../../../app/frontend/src/javascript/models/payment-schedule';
import { User } from '../../../../app/frontend/src/javascript/models/user';

jest.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key, options) => options?.AMOUNT ?? key })
}));
jest.mock('components/payment/stripe/stripe-confirm-modal', () => ({ StripeConfirmModal: () => null }));

test.each([38, 100, 0])('shows the actual cheque amount due (%s) in the confirmation dialog', amountDue => {
  render(<PaymentScheduleItemActions
    paymentScheduleItem={{ id: 1, amount: 100, amount_due: amountDue, due_date: '2026-11-21T09:00:00Z', state: 'pending', invoice_id: null, payment_method: null }}
    paymentSchedule={{ id: 1, payment_method: PaymentMethod.Check }}
    operator={{ role: 'admin' } as User}
    displayOnceMap={new Map()}
    onError={jest.fn()}
    onSuccess={jest.fn()}
    onCardUpdateSuccess={jest.fn()}
    show />);

  fireEvent.click(screen.getByRole('button', { name: 'app.shared.payment_schedule_item_actions.confirm_check' }));

  expect(screen.getByRole('dialog', { hidden: true }).querySelector('.fab-modal-content').textContent).toBe(FormatLib.price(amountDue));
});
