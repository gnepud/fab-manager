import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import selectEvent from 'react-select-event';
import { ProductStockModal } from 'components/store/product-stock-modal';

describe('ProductStockModal', () => {
  test.each([
    ['addition', 'inward_stock', 'withdrawal', 'sold'],
    ['withdrawal', 'sold', 'addition', 'inward_stock']
  ])('requires a new reason after switching away from %s (%s)', async (initialDirection, initialReason, nextDirection, nextReason) => {
    const onSuccess = jest.fn();
    const toggleModal = jest.fn();
    render(<ProductStockModal isOpen onSuccess={onSuccess} toggleModal={toggleModal} />);

    fireEvent.click(screen.getByRole('button', { name: `app.admin.store.product_stock_modal.${initialDirection}`, hidden: true }));
    await selectEvent.select(screen.getByLabelText(/product_stock_modal.stocks/), 'app.admin.store.product_stock_modal.external');
    fireEvent.change(screen.getByLabelText(/product_stock_modal.quantity/), { target: { value: '3' } });
    await selectEvent.select(screen.getByLabelText(/product_stock_modal.reason_type/), `app.admin.store.stock_movement_reason.${initialReason}`);

    fireEvent.click(screen.getByRole('button', { name: `app.admin.store.product_stock_modal.${nextDirection}`, hidden: true }));
    fireEvent.click(screen.getByRole('button', { name: /product_stock_modal.update_stock/, hidden: true }));

    const reasonField = screen.getByLabelText(/product_stock_modal.reason_type/).closest('.form-item');
    await waitFor(() => expect(reasonField).toHaveClass('is-incorrect'));
    expect(reasonField.querySelector('.form-item-error')).toBeInTheDocument();
    expect(onSuccess).not.toHaveBeenCalled();
    expect(toggleModal).not.toHaveBeenCalled();

    await selectEvent.select(screen.getByLabelText(/product_stock_modal.reason_type/), `app.admin.store.stock_movement_reason.${nextReason}`);
    fireEvent.click(screen.getByRole('button', { name: /product_stock_modal.update_stock/, hidden: true }));

    await waitFor(() => expect(onSuccess).toHaveBeenCalledWith({ stock_type: 'external', quantity: 3, reason: nextReason }));
    expect(onSuccess).toHaveBeenCalledTimes(1);
    expect(toggleModal).toHaveBeenCalledTimes(1);
  });
});
