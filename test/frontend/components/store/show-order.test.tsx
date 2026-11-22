import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import selectEvent from 'react-select-event';
import { ShowOrder } from 'components/store/show-order';
import OrderAPI from 'api/order';
import { Order } from 'models/order';
import orders from '../../__fixtures__/orders';
import { admins } from '../../__fixtures__/users';

jest.mock('components/base/text-editor/fab-text-editor', () => ({
  __esModule: true,
  default: ({ content, onChange, placeholder }) => (
    <textarea aria-label={placeholder} value={content} onChange={event => onChange(event.target.value)} />
  )
}));

const readyOrder: Order = { ...orders[0], state: 'ready', updated_at: '2022-12-06T16:15:00Z' };
const note = 'Collect at the side entrance';

const markReady = async () => {
  await act(async () => {
    await selectEvent.select(screen.getByRole('combobox'), 'app.shared.store.order_actions.state.ready');
  });
  fireEvent.change(screen.getByLabelText('app.shared.store.order_actions.order_ready_note'), { target: { value: note } });
  await act(async () => {
    fireEvent.click(screen.getByRole('button', { name: 'app.shared.store.order_actions.confirm', hidden: true }));
  });
};

describe('ShowOrder withdrawal instructions', () => {
  beforeEach(() => {
    jest.spyOn(OrderAPI, 'get').mockResolvedValue(orders[0]);
    jest.spyOn(OrderAPI, 'updateState').mockResolvedValue(readyOrder);
  });

  afterEach(() => jest.restoreAllMocks());

  test.each([
    ['custom HTML', `<strong>${note}</strong>`, note],
    ['empty instructions', '', '']
  ])('refreshes %s after marking the order ready', async (_name, instructions, expectedText) => {
    const withdrawalInstructions = jest.spyOn(OrderAPI, 'withdrawalInstructions')
      .mockResolvedValueOnce('<p>Default pickup instructions</p>')
      .mockResolvedValueOnce(instructions);
    const onSuccess = jest.fn();
    const onError = jest.fn();
    const { container } = render(<ShowOrder orderId="1" currentUser={admins[0]} onSuccess={onSuccess} onError={onError} />);
    await screen.findByText('Default pickup instructions');

    await markReady();

    await waitFor(() => expect(withdrawalInstructions).toHaveBeenLastCalledWith(readyOrder));
    await waitFor(() => expect(container.querySelector('.withdrawal-instructions p').textContent).toBe(expectedText));
    expect(screen.queryByText('Default pickup instructions')).not.toBeInTheDocument();
    expect(OrderAPI.updateState).toHaveBeenCalledWith(orders[0], 'ready', note);
    expect(onSuccess).toHaveBeenCalledWith('app.shared.store.order_actions.order_ready_success');
    expect(onError).not.toHaveBeenCalled();
  });

  test('reports an instructions refresh failure without undoing the successful state change', async () => {
    const error = new Error('Instructions unavailable');
    jest.spyOn(OrderAPI, 'withdrawalInstructions')
      .mockResolvedValueOnce('<p>Default pickup instructions</p>')
      .mockRejectedValueOnce(error);
    const onSuccess = jest.fn();
    const onError = jest.fn();
    render(<ShowOrder orderId="1" currentUser={admins[0]} onSuccess={onSuccess} onError={onError} />);
    await screen.findByText('Default pickup instructions');

    await markReady();

    await waitFor(() => expect(onError).toHaveBeenCalledWith(error));
    expect(onSuccess).toHaveBeenCalledWith('app.shared.store.order_actions.order_ready_success');
    expect(screen.getByText('app.shared.store.show_order.state.ready')).toBeInTheDocument();
  });
});
