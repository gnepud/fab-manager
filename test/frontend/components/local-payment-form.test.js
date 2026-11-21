import * as React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { readFileSync, readdirSync } from 'fs';
import { resolve } from 'path';
import { load } from 'js-yaml';
import { IntlMessageFormat } from 'intl-messageformat';
import { useTranslation } from 'react-i18next';
import { LocalPaymentForm } from 'components/payment/local-payment/local-payment-form';

jest.mock('react-i18next', () => ({ useTranslation: jest.fn() }));
jest.mock('components/payment/card-payment-modal', () => ({ CardPaymentModal: () => null }));

const locales = resolve(__dirname, '../../../config/locales');
const files = readdirSync(locales).filter(file => /^app\.admin\..*\.yml$/.test(file));
const messages = (file) => {
  const yaml = load(readFileSync(resolve(locales, file), 'utf8'));
  return Object.values(yaml)[0].app.admin.local_payment_form;
};

describe('LocalPaymentForm member confirmation', () => {
  test.each([
    ['fr', 'Vous êtes sur le point de confirmer votre pack prépayé.'],
    ['en', "You're about to confirm your prepaid pack."]
  ])('renders a prepaid pack cart in %s', (locale, wording) => {
    const translations = messages(`app.admin.${locale}.yml`);
    useTranslation.mockReturnValue({
      t: (key, values) => new IntlMessageFormat(translations[key.split('.').pop()], locale).format(values)
    });
    render(<LocalPaymentForm cart={{ items: [{ prepaid_pack: { id: 1 } }], payment_method: 'cash', customer_id: 1 }}
      customer={{ id: 1 }} operator={{ id: 1 }} formId="pack-checkout"
      updateCart={jest.fn()} onSubmit={jest.fn()} onSuccess={jest.fn()} onError={jest.fn()} />);
    expect(screen.getByText(wording)).toBeInTheDocument();
  });

  test.each(files)('%s explicitly handles packs and retains valid fallback cases', file => {
    const message = messages(file).about_to_confirm;
    expect(message).toMatch(/prepaid_pack\{/);
    const formatter = new IntlMessageFormat(message);
    for (const item of ['prepaid_pack', 'subscription', 'reservation', '', 'unknown']) {
      expect(formatter.format({ ITEM: item })).toEqual(expect.any(String));
      expect(formatter.format({ ITEM: item })).not.toBe('');
    }
    expect(formatter.format({ ITEM: 'prepaid_pack' })).not.toBe(formatter.format({ ITEM: 'unknown' }));
  });
});
