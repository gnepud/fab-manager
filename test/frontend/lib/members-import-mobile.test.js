import fs from 'fs';
import path from 'path';

describe('Members import header grid contract (not a layout test)', () => {
  let columns;
  let button;

  beforeAll(() => {
    const template = document.createElement('div');
    template.innerHTML = fs.readFileSync(path.resolve(__dirname, '../../../app/frontend/templates/admin/members/index.html'), 'utf8');
    columns = Array.from(template.querySelector('.heading > .row.no-gutter').children);
    button = template.querySelector('.import-members');
  });

  test('allocates three phone columns to the padded import action without an offset', () => {
    expect(columns[0].classList.contains('col-xs-2')).toBe(true);
    expect(columns[1].classList.contains('col-xs-7')).toBe(true);
    expect(columns[2].classList.contains('col-xs-3')).toBe(true);
    expect(Array.from(columns[2].classList).some(name => name.startsWith('col-xs-offset-'))).toBe(false);
    expect(columns[2].contains(button)).toBe(true);
  });

  test('allocates two tablet columns to the import action with a twelve-column row and no offset', () => {
    expect(columns[0].classList.contains('col-sm-2')).toBe(true);
    expect(columns[1].classList.contains('col-sm-8')).toBe(true);
    expect(columns[2].classList.contains('col-sm-2')).toBe(true);
    expect(Array.from(columns[2].classList).some(name => name.startsWith('col-sm-offset-'))).toBe(false);
  });

  test('explicitly restores the original desktop widths and offsets, inherited by large screens', () => {
    expect(columns[0].classList.contains('col-md-1')).toBe(true);
    expect(columns[1].classList.contains('col-md-8')).toBe(true);
    expect(columns[2].classList.contains('col-md-1')).toBe(true);
    expect(columns[2].classList.contains('col-md-offset-2')).toBe(true);
    expect(columns.every(column => Array.from(column.classList).every(name => !name.startsWith('col-lg-')))).toBe(true);
  });

  test('preserves the import action, admin visibility, and shared button styling', () => {
    expect(button.getAttribute('ui-sref')).toBe('app.admin.members_import');
    expect(button.getAttribute('role')).toBe('button');
    expect(button.matches('.btn.btn-default.b-2x.rounded.m-t-sm')).toBe(true);
    expect(button.parentElement.getAttribute('ng-show')).toBe("isAuthorized('admin')");
    expect(button.parentElement.classList.contains('wrapper')).toBe(true);
  });
});
