import angular from 'angular';
import i18next from 'i18next';
import { initReactI18next } from 'react-i18next';
import { act, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

jest.unmock('react-i18next');
jest.mock('components/dashboard/reservations/credits-panel', () => ({ CreditsPanel: () => null }));
jest.mock('components/dashboard/reservations/prepaid-packs-panel', () => ({ PrepaidPacksPanel: () => null }));
jest.mock('components/dashboard/reservations/reservations-panel', () => ({ ReservationsPanel: () => null }));

test('the Angular reservations tab renders once the logged translations load', async () => {
  const components = angular.module('reservationsDashboardTest', []);
  const registration = jest.spyOn(Application.Components, 'component')
    .mockImplementation((name, definition) => components.component(name, definition));
  require('components/dashboard/reservations/reservations-dashboard');
  registration.mockRestore();

  let finishLoading;
  const ready = i18next.createInstance().use(initReactI18next).use({
    type: 'backend',
    init () {},
    read (_language, _namespace, callback) {
      finishLoading = callback;
    }
  }).init({ lng: 'fr', fallbackLng: false, ns: ['logged'], initImmediate: false });

  const injector = angular.injector(['ng', components.name]);
  const scope = injector.get('$rootScope').$new();
  scope.member = { id: 1 };
  scope.admin = { role: 'admin' };
  const tab = angular.element('<reservations-dashboard user="member" current-user="admin"></reservations-dashboard>');
  document.body.appendChild(tab[0]);

  const title = 'Réservations de machines';
  try {
    act(() => {
      injector.get('$compile')(tab)(scope);
      scope.$digest();
    });
    expect(screen.queryByText(title)).not.toBeInTheDocument();

    await act(async () => {
      finishLoading(null, { app: { logged: { dashboard: { reservations_dashboard: { machine_section_title: title } } } } });
      await ready;
    });

    expect(await screen.findByText(title)).toBeInTheDocument();
  } finally {
    scope.$destroy();
    tab.remove();
  }
});
