import angular from 'angular';
import 'angular-sanitize';
import 'ngUpload';
import fs from 'fs';
import path from 'path';

describe('member import upload responses', () => {
  let scope;
  let element;
  let form;
  let iframe;
  let growl;
  let state;
  let translate;
  const fallback = 'The file could not be uploaded. Please choose a valid CSV file and try again.';

  beforeAll(() => {
    Application.Controllers = angular.module('membersImportUploadTest', ['ngUpload', 'ngSanitize'])
      .filter('translate', () => value => value);
    Application.Filters = Application.Controllers;
    require('../../../app/frontend/src/javascript/filters/filters');
    require('../../../app/frontend/src/javascript/controllers/admin/members');
  });

  beforeEach(() => {
    const injector = angular.injector(['ng', 'membersImportUploadTest']);
    scope = injector.get('$rootScope').$new();
    growl = { error: jest.fn() };
    state = { go: jest.fn() };
    translate = jest.fn(() => fallback);
    injector.get('$controller')('ImportMembersController', {
      $scope: scope,
      $state: state,
      Group: { query: onSuccess => onSuccess([]) },
      Training: { query: () => ({ $promise: Promise.resolve([]) }) },
      CSRF: { setMetaTags: jest.fn() },
      tags: [],
      growl,
      _t: translate
    });
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/members/import.html'), 'utf8');
    element = injector.get('$compile')(template)(scope);
    angular.element(document.body).append(element);
    scope.$digest();
    form = angular.element(element[0].querySelector('form'));
    iframe = element[0].querySelector('iframe');
    jest.spyOn(injector.get('$log'), 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    scope.$destroy();
    element.remove();
    jest.restoreAllMocks();
  });

  function startUpload () {
    form.triggerHandler('submit');
    expect(scope.$isUploading).toBe(true);
    expect(form[0].querySelector('[type="submit"]').disabled).toBe(true);
  }

  function respond (body) {
    iframe.contentDocument.body.textContent = body;
    angular.element(iframe).triggerHandler('load');
    expect(scope.$isUploading).toBe(false);
    expect(form[0].querySelector('[type="submit"]').disabled).toBe(false);
  }

  test.each([
    { attachment: ['You are not allowed to upload "txt" files, allowed types: csv'] },
    { attachment: 'You are not allowed to upload application/pdf files, allowed types: text/csv' },
    { attachment: ['File is invalid.', 'Please use CSV.'] }
  ])('shows one readable server-validation toast for %j and allows retry', content => {
    startUpload();
    respond(JSON.stringify(content));

    const messages = Array.isArray(content.attachment) ? content.attachment : [content.attachment];
    expect(growl.error).toHaveBeenCalledTimes(1);
    expect(growl.error).toHaveBeenCalledWith(messages.join(' '));
    expect(state.go).not.toHaveBeenCalled();

    startUpload();
    respond('{"id":42}');
    expect(state.go).toHaveBeenCalledWith('app.admin.members_import_result', { id: 42 });
    expect(growl.error).toHaveBeenCalledTimes(1);
  });

  test.each([
    '<html><body>Internal Server Error</body></html>',
    '',
    'null',
    '{}',
    '{"attachment":[]}',
    '{"attachment":[null]}',
    '{"attachment":["<h1>Internal Server Error</h1>"]}'
  ])('uses the translated fallback for an unreadable or empty response: %s', body => {
    startUpload();
    respond(body);

    expect(growl.error).toHaveBeenCalledTimes(1);
    expect(growl.error).toHaveBeenCalledWith(fallback);
    expect(translate).toHaveBeenCalledWith('app.admin.members_import.upload_failed');
    expect(state.go).not.toHaveBeenCalled();
  });

  test('uses the translated fallback when the iframe response cannot be accessed', () => {
    startUpload();
    Object.defineProperty(iframe, 'contentDocument', { get: () => { throw new Error('Blocked iframe access'); } });
    angular.element(iframe).triggerHandler('load');

    expect(growl.error).toHaveBeenCalledTimes(1);
    expect(growl.error).toHaveBeenCalledWith(fallback);
    expect(scope.$isUploading).toBe(false);
    expect(form[0].querySelector('[type="submit"]').disabled).toBe(false);
  });

  test('opens the results page after a successful upload without an error toast', () => {
    startUpload();
    respond('{"id":42}');

    expect(state.go).toHaveBeenCalledWith('app.admin.members_import_result', { id: 42 });
    expect(growl.error).not.toHaveBeenCalled();
  });
});
