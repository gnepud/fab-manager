import angular from 'angular';
import fs from 'fs';
import path from 'path';
import 'angular-i18n/angular-locale_fr-fr';

describe('statistics custom aggregates', () => {
  let scope;
  let element;

  beforeEach(() => {
    const injector = angular.injector(['ng', 'ngLocale']);
    scope = injector.get('$rootScope').$new();
    const template = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/statistics/index.html'), 'utf8');
    const line = template.split('\n').find(line => line.includes('ng-repeat="custom in type.active.custom_aggregations"'));
    scope.type = { active: { custom_aggregations: [{ field: 'value', data_type: 'currency' }] } };
    scope.customFieldName = () => 'Aggregate:';
    scope.customAggs = { value: 49.699999999999996 };
    element = injector.get('$compile')(line)(scope);
  });

  const rendered = element => element.parent().text().replace(/\s/g, ' ').trim();

  test('formats monetary aggregates using the current locale', () => {
    const container = angular.element('<ul></ul>');
    container.append(element);
    scope.$digest();
    expect(rendered(element)).toBe('Aggregate: 49,70 €');
  });

  test('rounds non-monetary aggregates without adding a currency symbol', () => {
    const container = angular.element('<ul></ul>');
    container.append(element);
    scope.type.active.custom_aggregations[0].data_type = 'number';
    scope.$digest();
    expect(rendered(element)).toBe('Aggregate: 49,70');
  });

  test.each([null, undefined])('leaves missing aggregate %s empty', value => {
    const container = angular.element('<ul></ul>');
    container.append(element);
    scope.customAggs.value = value;
    scope.$digest();
    expect(rendered(element)).toBe('Aggregate:');
  });

  test.each(['currency', 'number'])('preserves zero for %s aggregates', dataType => {
    const container = angular.element('<ul></ul>');
    container.append(element);
    scope.type.active.custom_aggregations[0].data_type = dataType;
    scope.customAggs.value = 0;
    scope.$digest();
    expect(rendered(element)).toBe(dataType === 'currency' ? 'Aggregate: 0,00 €' : 'Aggregate: 0,00');
  });
});
