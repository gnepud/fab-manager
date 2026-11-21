import angular from 'angular';
import moment from 'moment';

describe('InvoicesController VAT preview', () => {
  let injector;
  let scope;

  beforeAll(() => {
    global.moment = moment;
    const controllers = angular.module('invoicesControllerTest', []);
    Application.Controllers = controllers;
    require('controllers/admin/invoices');
    injector = angular.injector(['ng', controllers.name]);
  });

  afterAll(() => { delete global.moment; });

  afterEach(() => { scope.$destroy(); });

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
      Setting,
      settings,
      stripeSecretKey: {},
      _t: key => key,
      Member: {},
      uiTourService: {},
      Payment: {},
      onlinePaymentStatus: {},
      $uiRouter: {}
    });

    expect(scope.invoice.VAT.active).toBe(!active);

    scope.onVATSuccess('VAT settings saved');

    expect(scope.invoice.VAT.active).toBe(active);
  });
});
