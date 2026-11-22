import { render, fireEvent, screen, within } from '@testing-library/react';
import '@testing-library/jest-dom';
import { PaymentSchedulesTable } from '../../../../app/frontend/src/javascript/components/payment-schedule/payment-schedules-table';
import { PaymentMethod, PaymentSchedule } from '../../../../app/frontend/src/javascript/models/payment-schedule';
import { User } from '../../../../app/frontend/src/javascript/models/user';
import SettingAPI from '../../../../app/frontend/src/javascript/api/setting';

jest.mock('../../../../app/frontend/src/javascript/api/setting');

describe('PaymentSchedulesTable', () => {
  const cancelButton = 'app.shared.payment_schedule_item_actions.cancel_subscription';
  const props = {
    operator: { role: 'admin' } as User,
    refreshList: jest.fn(),
    onError: jest.fn(),
    onCardUpdateSuccess: jest.fn()
  };

  beforeEach(() => {
    (SettingAPI.get as jest.Mock).mockResolvedValue({ value: null });
  });

  test('moves the cancel subscription button to the next unpaid installment after refresh', async () => {
    const schedule: PaymentSchedule = {
      id: 1,
      reference: 'SCHEDULE-1',
      payment_method: PaymentMethod.Card,
      total: 9000,
      items: [
        { id: 1, amount: 3000, due_date: '2026-01-01T00:00:00Z', state: 'paid', invoice_id: 1, payment_method: PaymentMethod.Card },
        { id: 2, amount: 3000, due_date: '2026-02-01T00:00:00Z', state: 'error', invoice_id: null, payment_method: null },
        { id: 3, amount: 3000, due_date: '2026-03-01T00:00:00Z', state: 'new', invoice_id: null, payment_method: null }
      ]
    };
    const { container, rerender } = render(<PaymentSchedulesTable {...props} paymentSchedules={[schedule]} />);
    await screen.findByText('SCHEDULE-1');
    fireEvent.click(container.querySelector('.row-header'));
    const rows = container.querySelectorAll('.schedule-items-table tbody tr');
    expect(within(rows[1] as HTMLElement).getByRole('button', { name: cancelButton })).toBeVisible();
    expect(screen.getAllByRole('button', { name: cancelButton })).toHaveLength(1);

    rerender(<PaymentSchedulesTable {...props} paymentSchedules={[{
      ...schedule,
      items: schedule.items.map(item => item.id === 2 ? { ...item, state: 'paid', payment_method: PaymentMethod.Transfer, invoice_id: 2 } : item)
    }]} />);

    expect(within(rows[2] as HTMLElement).getByRole('button', { name: cancelButton })).toBeVisible();
    expect(screen.getAllByRole('button', { name: cancelButton })).toHaveLength(1);
  });
});
