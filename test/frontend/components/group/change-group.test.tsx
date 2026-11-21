import { ChangeGroup } from '../../../../app/frontend/src/javascript/components/group/change-group';
import { render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { rest } from 'msw';
import { server } from '../../__setup__/server';
import { loginAs } from '../../__lib__/auth';
import { members } from '../../__fixtures__/users';
import groups from '../../__fixtures__/groups';

describe('ChangeGroup', () => {
  const onSuccess = jest.fn();
  const onError = jest.fn();
  let requestedPaths: Array<string>;

  const trackRequest = (req) => requestedPaths.push(req.url.pathname);

  beforeEach(() => {
    jest.clearAllMocks();
    requestedPaths = [];
    server.events.on('request:start', trackRequest);
  });

  afterEach(() => {
    server.events.removeListener('request:start', trackRequest);
  });

  test('does not request the current member nor report an error for a visitor', async () => {
    server.use(
      rest.get('/api/members/current', (req, res, ctx) => {
        return res(ctx.status(401), ctx.json({ error: 'You need to sign in or sign up before continuing.' }));
      })
    );

    render(<ChangeGroup user={null} onSuccess={onSuccess} onError={onError} />);

    await waitFor(() => expect(requestedPaths).toContain('/api/settings/user_change_group'));
    expect(requestedPaths).not.toContain('/api/members/current');
    expect(onError).not.toHaveBeenCalled();
  });

  test('requests the current member once a user is provided', async () => {
    loginAs(members[0]);
    const { rerender } = render(<ChangeGroup user={null} onSuccess={onSuccess} onError={onError} />);
    rerender(<ChangeGroup user={members[0]} onSuccess={onSuccess} onError={onError} />);

    await waitFor(() => expect(requestedPaths).toContain('/api/members/current'));
    await waitFor(() => expect(screen.getByText(groups.find(g => g.id === members[0].group_id).name)).toBeInTheDocument());
    expect(onError).not.toHaveBeenCalled();
  });
});
