/**
 * @jest-environment ./test/frontend/__setup__/timezone-environment.js
 */
/* global setTimezone */
import angular from 'angular';
import moment from 'moment';

let injector;
let scope;

const buildController = (overrides = {}) => {
  scope = injector.get('$rootScope').$new();
  injector.get('$controller')('InvoicesController', {
    $scope: scope,
    $state: {},
    Invoice: {},
    AccountingPeriod: {},
    AuthService: {},
    invoices: [],
    closedPeriods: [],
    $uibModal: {},
    growl: { success: jest.fn() },
    Setting: {},
    settings: {},
    stripeSecretKey: {},
    _t: key => key,
    Member: {},
    uiTourService: {},
    Payment: {},
    onlinePaymentStatus: {},
    $uiRouter: {},
    ...overrides
  });
};

beforeAll(() => {
  global.moment = moment;
  const controllers = angular.module('invoicesControllerTest', []);
  Application.Controllers = controllers;
  require('controllers/admin/invoices');
  injector = angular.injector(['ng', controllers.name]);
});

afterAll(() => { delete global.moment; });

afterEach(() => { scope.$destroy(); });

describe('InvoicesController VAT preview', () => {
  test.each([
    ['false', 'true', true],
    ['true', 'false', false]
  ])('refreshes the preview after saving VAT active from %s to %s', (initial, saved, active) => {
    const settings = { 'invoice_VAT-active': initial, 'invoice_VAT-rate': '20', 'invoice_VAT-name': 'TVA' };
    const savedSettings = { ...settings, 'invoice_VAT-active': saved };
    const Setting = {
      query ({ names }, success) {
        success(Object.fromEntries(Object.entries(savedSettings).filter(([name]) => names.includes(`'${name}'`))));
      }
    };
    buildController({ Setting, settings });

    expect(scope.invoice.VAT.active).toBe(!active);

    scope.onVATSuccess('VAT settings saved');

    expect(scope.invoice.VAT.active).toBe(active);
  });
});

describe('InvoicesController date filter', () => {
  afterEach(() => {
    jest.useRealTimers();
    setTimezone('UTC');
  });

  test.each(['Europe/Paris', 'America/New_York', 'UTC', 'Pacific/Kiritimati'])('searches the picked calendar day in %s', timezone => {
    setTimezone(timezone);
    jest.useFakeTimers();
    const Invoice = { list: jest.fn() };
    buildController({ Invoice });

    scope.searchInvoice.date = new Date(2026, 10, 21);
    scope.handleFilterChange();
    jest.runAllTimers();

    expect(Invoice.list).toHaveBeenCalledTimes(1);
    expect(Invoice.list.mock.calls[0][0].query.date).toBe('2026-11-21');
  });
});
