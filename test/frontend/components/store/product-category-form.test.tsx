import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { rest } from 'msw';
import { ProductCategoryForm } from 'components/store/categories/product-category-form';
import categories from '../../__fixtures__/product_categories';
import { server } from '../../__setup__/server';

describe('ProductCategoryForm validation errors', () => {
  test.each(['create', 'update'] as const)('displays a readable hierarchy error on %s', async action => {
    const message = 'Categories can have only two levels: choose a root parent, and do not assign a parent to a category with children or to itself.';
    const rejectHierarchy = (_req, res, ctx) => res(ctx.status(422), ctx.json([message]));
    server.use(
      rest.post('/api/product_categories', rejectHierarchy),
      rest.patch('/api/product_categories/:id', rejectHierarchy)
    );
    const onSuccess = jest.fn();
    const onError = jest.fn();
    render(<ProductCategoryForm action={action}
                                productCategories={categories}
                                productCategory={categories[0]}
                                onSuccess={onSuccess}
                                onError={onError} />);

    fireEvent.click(screen.getByRole('button', { name: 'app.admin.store.product_category_form.save' }));

    await waitFor(() => expect(onError).toHaveBeenCalledWith(`app.admin.store.product_category_form.${action}.error${message}`));
    expect(onSuccess).not.toHaveBeenCalled();
  });
});
