import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import i18next from 'i18next';
import ICU from 'i18next-icu';
import { I18nextProvider } from 'react-i18next';
import ProductAPI from '../../../../app/frontend/src/javascript/api/product';
import { ProductItem } from '../../../../app/frontend/src/javascript/components/store/product-item';
import products from '../../__fixtures__/products';

jest.unmock('react-i18next');

const i18n = i18next.createInstance();

beforeAll(async () => {
  await i18n.use(ICU).init({
    lng: 'fr',
    fallbackLng: false,
    resources: {
      fr: {
        admin: {
          app: {
            admin: {
              edit_destroy_buttons: {
                confirm_delete: 'Supprimer',
                deleted: 'Le {TYPE} a bien été supprimé.',
                unable_to_delete: 'Impossible de supprimer le {TYPE} : '
              },
              store: { product_item: { product: 'produit' } }
            }
          }
        }
      }
    }
  });
});

afterEach(() => jest.restoreAllMocks());

function confirmDeletion () {
  const onDelete = jest.fn();
  const onError = jest.fn();
  const product = products[1];
  const { container } = render(
    <I18nextProvider i18n={i18n}>
      <ProductItem product={product} onEdit={jest.fn()} onDelete={onDelete} onError={onError} />
    </I18nextProvider>
  );

  fireEvent.click(container.querySelector('.delete-btn'));
  fireEvent.click(screen.getByText('Supprimer', { selector: 'button' }));
  expect(ProductAPI.destroy).toHaveBeenCalledWith(product.id);

  return { onDelete, onError };
}

test('names the product type after a successful deletion', async () => {
  jest.spyOn(ProductAPI, 'destroy').mockResolvedValue(undefined);
  const { onDelete } = confirmDeletion();

  await waitFor(() => expect(onDelete).toHaveBeenCalledWith('Le produit a bien été supprimé.'));
});

test('names the product type and preserves the error after a failed deletion', async () => {
  jest.spyOn(ProductAPI, 'destroy').mockRejectedValue('suppression refusée');
  const { onError } = confirmDeletion();

  await waitFor(() => expect(onError).toHaveBeenCalledWith('Impossible de supprimer le produit : suppression refusée'));
});
