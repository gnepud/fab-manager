import angular from 'angular';
import $ from 'jquery';
import moment from 'moment-timezone';

describe('AccountingExportModalController', () => {
  let scope;
  let exportStatus;

  beforeAll(() => {
    moment.tz.setDefault('Europe/Paris');
    global.moment = moment;
    Application.Controllers = angular.module('accountingExportControllerTest', []);
    require('../../../app/frontend/src/javascript/controllers/admin/invoices');
  });

  afterAll(() => {
    moment.tz.setDefault();
    delete global.moment;
  });

  beforeEach(() => {
    jest.spyOn(angular, 'element').mockImplementation($);
    document.head.innerHTML = '<meta name="csrf-token" content="test-token">';
    scope = {};
    exportStatus = jest.fn(() => Promise.resolve({ data: { exists: true } }));
    angular.injector(['ng', 'accountingExportControllerTest']).get('$controller')('AccountingExportModalController', {
      $scope: scope,
      $uibModalInstance: { close: jest.fn() },
      Invoice: { first: onFirst => onFirst({ date: '2026-01-01T00:00:00Z' }) },
      Export: { status: exportStatus },
      CSRF: { setMetaTags: jest.fn() },
      growl: { success: jest.fn() },
      _t: jest.fn()
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test.each(['vat', 'acd'])('exports the selected Paris calendar day for %s', async software => {
    scope.exportTarget.software = software;
    scope.fillSettings(software);
    scope.exportTarget.startDate = new Date('2026-11-22T00:00:00+01:00');
    scope.exportTarget.endDate = new Date('2026-11-22T00:00:00+01:00');

    scope.ok();

    expect(exportStatus).toHaveBeenCalledTimes(1);
    expect(JSON.parse(exportStatus.mock.calls[0][0].query)).toMatchObject({
      start_date: '2026-11-21T23:00:00.000Z',
      end_date: '2026-11-22T22:59:59.999Z'
    });
    await Promise.resolve();
  });
});
