import angular from 'angular';
import i18next from 'i18next';
import { initReactI18next } from 'react-i18next';
import { act, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

jest.unmock('react-i18next');

test('the Angular accounting codes tab renders once the admin translations load', async () => {
  const components = angular.module('accountingCodesSettingsTest', []);
  const registration = jest.spyOn(Application.Components, 'component')
    .mockImplementation((name, definition) => components.component(name, definition));
  require('components/accounting/accounting-codes-settings');
  registration.mockRestore();

  let finishLoading;
  const ready = i18next.createInstance().use(initReactI18next).use({
    type: 'backend',
    init () {},
    read (_language, _namespace, callback) {
      finishLoading = callback;
    }
  }).init({ lng: 'en', fallbackLng: false, ns: ['admin'], initImmediate: false });

  const injector = angular.injector(['ng', components.name]);
  const scope = injector.get('$rootScope').$new();
  const tab = angular.element('<accounting-codes-settings></accounting-codes-settings>');
  document.body.appendChild(tab[0]);

  try {
    act(() => {
      injector.get('$compile')(tab)(scope);
      scope.$digest();
    });
    expect(screen.queryByRole('heading', { name: 'Advanced accounting' })).not.toBeInTheDocument();

    await act(async () => {
      finishLoading(null, { app: { admin: { accounting_codes_settings: { advanced_accounting: 'Advanced accounting' } } } });
      await ready;
    });

    expect(await screen.findByRole('heading', { name: 'Advanced accounting' })).toBeInTheDocument();
    expect(await screen.findByDisplayValue('CB01')).toBeInTheDocument();
  } finally {
    scope.$destroy();
    tab.remove();
  }
});
