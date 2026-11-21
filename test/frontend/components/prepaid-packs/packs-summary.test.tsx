import { act, render, screen } from '@testing-library/react';
import PrepaidPackAPI from '../../../../app/frontend/src/javascript/api/prepaid-pack';
import SettingAPI from '../../../../app/frontend/src/javascript/api/setting';
import UserPackAPI from '../../../../app/frontend/src/javascript/api/user-pack';
import { PacksSummary } from '../../../../app/frontend/src/javascript/components/prepaid-packs/packs-summary';
import { members } from '../../__fixtures__/users';

jest.mock('../../../../app/frontend/src/javascript/components/prepaid-packs/propose-packs-modal', () => ({
  ProposePacksModal: () => null
}));

const member = members[0];
const machine = { id: 1, name: 'Laser cutter', slug: 'laser-cutter', disabled: false, reservable: true, space: { name: 'Workshop' } };
const buyPackButton = { name: 'app.logged.packs_summary.buy_a_new_pack' };
const remainingHours = 'app.logged.packs_summary.remaining_HOURS';

afterEach(() => jest.restoreAllMocks());

async function renderSummary (threshold: string, minutesUsed: number, { forSale = true, subscriptionRequired = false } = {}) {
  const onError = jest.fn();
  jest.spyOn(SettingAPI, 'get').mockImplementation(async name => ({
    name,
    value: name === 'renew_pack_threshold' ? threshold : String(subscriptionRequired)
  }));
  jest.spyOn(PrepaidPackAPI, 'index').mockResolvedValue(forSale ? [{ id: 1, group_id: member.group_id, minutes: 120, amount: 2000 }] : []);
  jest.spyOn(UserPackAPI, 'index').mockResolvedValue([{
    id: 1,
    minutes_used: minutesUsed,
    expires_at: null,
    prepaid_pack: { minutes: 120, priceable_type: 'Machine', priceable: { name: machine.name } }
  }]);

  await act(async () => {
    render(<PacksSummary item={machine} itemType="Machine" operator={member} customer={member} onError={onError} onSuccess={jest.fn()} />);
  });
  expect(onError).not.toHaveBeenCalled();
}

test.each(['1.25', '0.6'])('offers renewal alongside the remaining hour at threshold %s', async threshold => {
  await renderSummary(threshold, 60);

  expect(screen.getByText(remainingHours)).toBeTruthy();
  expect(screen.getByRole('button', buyPackButton)).toBeTruthy();
});

test.each(['1.25', '0.6'])('does not offer renewal above threshold %s', async threshold => {
  await renderSummary(threshold, 30);

  expect(screen.getByText(remainingHours)).toBeTruthy();
  expect(screen.queryByRole('button', buyPackButton)).toBeNull();
});

test('still offers renewal when all prepaid hours are used', async () => {
  await renderSummary('0.6', 120);

  expect(screen.getByText('app.logged.packs_summary.no_hours')).toBeTruthy();
  expect(screen.getByRole('button', buyPackButton)).toBeTruthy();
});

test('does not offer renewal without a pack for sale', async () => {
  await renderSummary('1.25', 60, { forSale: false });

  expect(screen.getByText(remainingHours)).toBeTruthy();
  expect(screen.queryByRole('button', buyPackButton)).toBeNull();
});

test('shows the warning instead of offering renewal when a subscription is required', async () => {
  await renderSummary('1.25', 60, { subscriptionRequired: true });

  expect(screen.getByText(remainingHours)).toBeTruthy();
  expect(screen.getByRole('alert').textContent).toBe('app.logged.packs_summary.unable_to_use_pack_for_subsription_is_expired');
  expect(screen.queryByRole('button', buyPackButton)).toBeNull();
});
