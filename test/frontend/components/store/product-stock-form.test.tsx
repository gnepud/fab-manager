import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { useForm } from 'react-hook-form';
import selectEvent from 'react-select-event';
import { ProductStockForm } from 'components/store/product-stock-form';
import ProductAPI from 'api/product';
import { Product } from 'models/product';
import products from '../../__fixtures__/products';
import movements from '../../__fixtures__/product_stock_movements';

const product = { ...products[0], product_stock_movements_attributes: [] };

const StockForm = ({ onError }: { onError: (message: string) => void }) => {
  const { register, control, formState, setValue } = useForm<Product>({ defaultValues: product });
  return <ProductStockForm currentFormValues={product} register={register} control={control}
                           formState={formState} setValue={setValue} onSuccess={jest.fn()} onError={onError} />;
};

describe('ProductStockForm history filters', () => {
  afterEach(() => jest.restoreAllMocks());

  test.each([
    [0, 'app.admin.store.stock_movement_reason.sold', { reason: 'sold' }],
    [1, 'app.admin.store.product_stock_form.external', { stock_type: 'external' }]
  ])('resets page two when changing filter %s', async (filterIndex: number, label: string, expectedFilter: object) => {
    const onError = jest.fn();
    const stockMovements = jest.spyOn(ProductAPI, 'stockMovements').mockImplementation(async (_id, filters) => {
      const filtered = Boolean(filters.reason || filters.stock_type);
      return {
        data: filtered && filters.page > 1 ? [] : [movements[0]],
        page: filters.page,
        page_size: 10,
        total_pages: filtered ? 1 : 2,
        total_count: filtered ? 1 : 11
      };
    });
    render(<StockForm onError={onError} />);

    fireEvent.click(await screen.findByRole('button', { name: '2' }));
    await waitFor(() => expect(stockMovements).toHaveBeenLastCalledWith(product.id, { page: 2 }));
    expect(screen.getByRole('button', { name: '2' })).toHaveClass('is-active');

    await act(async () => {
      await selectEvent.select(screen.getAllByRole('combobox')[filterIndex], label);
    });

    await waitFor(() => expect(stockMovements).toHaveBeenLastCalledWith(product.id, { page: 1, ...expectedFilter }));
    await waitFor(() => expect(screen.getAllByRole('listitem')).toHaveLength(1));
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
    expect(onError).not.toHaveBeenCalled();
  });
});
