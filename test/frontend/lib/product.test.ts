import ProductLib from 'lib/product';

describe('ProductLib.readFiltersFromUrl', () => {
  test.each([
    ['Laser wood', ['Laser wood']],
    ['123', ['123']],
    ['true', ['true']],
    ['false', ['false']],
    [['Laser wood', 'Lamp'], ['Laser wood', 'Lamp']],
    [[], []],
    ['', []],
    [undefined, []],
    [null, []]
  ])('preserves keyword filters from %p', (keywords, expected) => {
    const filters = ProductLib.readFiltersFromUrl({ keywords }, [], []);

    expect(filters.keywords).toEqual(expected);
  });

  test('uses default filters when no keyword parameter is present', () => {
    expect(ProductLib.readFiltersFromUrl({}, [], []).keywords).toEqual([]);
  });
});
