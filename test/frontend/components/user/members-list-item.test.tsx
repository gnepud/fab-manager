import { fireEvent, render } from '@testing-library/react';
import '@testing-library/jest-dom';
import { MembersListItem } from '../../../../app/frontend/src/javascript/components/user/members-list-item';
import { Member } from '../../../../app/frontend/src/javascript/models/member';
import { User } from '../../../../app/frontend/src/javascript/models/user';
import { admins, managers } from '../../__fixtures__/users';

const member = {
  id: 7,
  email: 'victor.hugo@example.com',
  profile: { first_name: 'Victor', last_name: 'Hugo', phone: null },
  group: { name: 'Standard' },
  validated_at: null,
  children: []
} as Member;

const renderItem = (operator: User, onDeleteMember = jest.fn()) => render(
  <MembersListItem member={member} operator={operator} onDeleteMember={onDeleteMember}
                   onError={jest.fn()} onSuccess={jest.fn()} onEditChild={jest.fn()} onDeleteChild={jest.fn()} />
);

describe('MembersListItem', () => {
  test('admins can delete the member', () => {
    const onDeleteMember = jest.fn();
    const { container } = renderItem(admins[0], onDeleteMember);

    expect(container.querySelector('.edit-btn')).toBeInTheDocument();
    fireEvent.click(container.querySelector('.delete-btn'));
    expect(onDeleteMember).toHaveBeenCalledWith(member.id);
  });

  test('managers cannot delete the member', () => {
    const { container } = renderItem(managers[0]);

    expect(container.querySelector('.edit-btn')).toBeInTheDocument();
    expect(container.querySelector('.delete-btn')).not.toBeInTheDocument();
  });
});
