import angular from 'angular';
import moment from 'moment';
import lodash from 'lodash';

describe('ng-upload controller errors', () => {
  beforeAll(() => {
    global.moment = moment;
    global._ = lodash;
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
    delete global._;
    delete global.$;
  });

  afterEach(() => {
    delete Fablab.sessionTourMode;
    Fablab.sessionTours = [];
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
    let rootScope;
    let member;

    beforeEach(() => {
      scope = { currentUser: { id: 1 }, $watch: jest.fn() };
      rootScope = { currentUser: { id: 1 }, summernoteOpts: { toolbar: Array.from({ length: 7 }, () => ['', []]) } };
      member = { merge: jest.fn() };
      const query = { query: () => ({ $promise: Promise.resolve([]) }) };
      angular.injector(['ng', 'uploadErrorsControllerTest']).get('$controller')(controller, {
        $scope: scope,
        $rootScope: rootScope,
        $state: { go: jest.fn() },
        $window: {},
        $sce: {},
        $cookies: { get: jest.fn() },
        $injector: {},
        Project: {},
        Machine: query,
        Member: member,
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
        growl: { success: jest.fn() },
        Auth: { _currentUser: { profile_attributes: {} } },
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

    if (['CompleteProfileController', 'EditProfileController'].includes(controller)) {
      test.each(['submited', 'onSuccess'])('%s preserves session history when publishing an updated user', callback => {
        Fablab.sessionTourMode = true;
        Fablab.sessionTours = ['calendar'];
        scope.currentUser.profile_attributes = {};
        scope.user = { profile_attributes: {} };
        const user = { id: 1, profile_attributes: { tours: ['welcome'] } };
        scope[callback](user);
        expect(rootScope.currentUser.profile_attributes.tours).toBe(Fablab.sessionTours);
      });
    }

    if (controller === 'CompleteProfileController') {
      test('preserves session history after merging an account', () => {
        Fablab.sessionTourMode = true;
        Fablab.sessionTours = ['calendar'];
        scope.user.auth_token = 'token';
        member.merge.mockImplementation((_params, _body, callback) => callback({ id: 1, profile_attributes: { tours: ['welcome'] } }));
        scope.registerAuthToken();
        expect(rootScope.currentUser.profile_attributes.tours).toBe(Fablab.sessionTours);
      });
    }
  });
});
