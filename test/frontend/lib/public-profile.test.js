import angular from 'angular';
import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';
import 'angular-translate';

describe('public profile project role badge', () => {
  const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/shared/publicProfile.html.erb'), 'utf8');
  const badge = template.match(/{{project.author_id == user.id[^}]+}}/)[0];

  test.each([
    ['fr', 1, 'Auteur'],
    ['fr', 2, 'Collaborateur'],
    ['en', 1, 'Author'],
    ['en', 2, 'Collaborator']
  ])('renders the %s role for author %s', (locale, authorId, expected) => {
    const translations = yaml.load(fs.readFileSync(path.resolve(__dirname, `../../../config/locales/app.shared.${locale}.yml`), 'utf8'));
    angular.module('publicProfileBadgeTest', ['pascalprecht.translate'])
      .config(['$translateProvider', provider => {
        provider.translations(locale, translations[locale]);
        provider.preferredLanguage(locale);
        provider.useSanitizeValueStrategy('escape');
      }]);
    const injector = angular.injector(['ng', 'publicProfileBadgeTest']);
    const scope = injector.get('$rootScope').$new();
    scope.user = { id: 1 };
    scope.project = { author_id: authorId };
    const element = injector.get('$compile')(`<span>${badge}</span>`)(scope);
    scope.$digest();
    expect(element.text()).toBe(expected);
    scope.$destroy();
  });
});
