import angular from 'angular';
import moment from 'moment';

describe('ng-upload controller errors', () => {
  beforeAll(() => {
    global.moment = moment;
    global.$ = jest.fn(() => ({ scrollTop: jest.fn() }));
    Application.Controllers = angular.module('uploadErrorsControllerTest', []);
    require('../../../app/frontend/src/javascript/controllers/projects');
    require('../../../app/frontend/src/javascript/controllers/profile');
    require('../../../app/frontend/src/javascript/controllers/members');
    require('../../../app/frontend/src/javascript/controllers/machines.js.erb');
    require('../../../app/frontend/src/javascript/controllers/spaces.js.erb');
    require('../../../app/frontend/src/javascript/controllers/admin/trainings');
    require('../../../app/frontend/src/javascript/controllers/admin/members');
  });

  afterAll(() => {
    delete global.moment;
    delete global.$;
  });

  describe.each([
    'NewProjectController',
    'CompleteProfileController',
    'EditProfileController',
    'NewMachineController',
    'NewSpaceController',
    'NewTrainingController',
    'NewMemberController'
  ])('%s', (controller) => {
    let scope;

    beforeEach(() => {
      scope = { currentUser: { id: 1 }, $watch: jest.fn() };
      const query = { query: () => ({ $promise: Promise.resolve([]) }) };
      angular.injector(['ng', 'uploadErrorsControllerTest']).get('$controller')(controller, {
        $scope: scope,
        $rootScope: { summernoteOpts: { toolbar: Array.from({ length: 7 }, () => ['', []]) } },
        $state: { go: jest.fn() },
        $window: {},
        $sce: {},
        $cookies: { get: jest.fn() },
        $injector: {},
        Project: {},
        Machine: query,
        Member: {},
        Component: query,
        Theme: query,
        ProjectCategory: query,
        Licence: query,
        Status: query,
        Training: query,
        Group: { query: onSuccess => onSuccess([]) },
        CSRF: { setMetaTags: jest.fn() },
        Diacritics: {},
        dialogs: {},
        allowedExtensions: { setting: { value: 'pdf' } },
        projectCategoriesWording: { setting: { value: '' } },
        _t: key => key,
        growl: {},
        Auth: {},
        Session: {},
        settingsPromise: {},
        activeProviderPromise: { providable_type: 'DatabaseProvider', mapping: [] },
        groupsPromise: [],
        groups: [],
        cguFile: {},
        memberPromise: { id: 1, statistic_profile_attributes: {} },
        AuthProvider: {},
        proofOfIdentityTypesPromise: [],
        SupportingDocumentType: {}
      });
    });

    test.each([
      [{ error: 'You have to confirm your email address before continuing.' }, ['error: You have to confirm your email address before continuing.']],
      [{ name: ['cannot be blank', 'is invalid'], image: ['must be an image'] }, ['name: cannot be blank', 'name: is invalid', 'image: must be an image']],
      [{}, []],
      [{ image: [] }, []]
    ])('preserves whole messages for %j', (content, messages) => {
      scope.submited(content);

      expect(scope.alerts).toEqual(messages.map(msg => ({ msg, type: 'danger' })));
    });
  });
});
