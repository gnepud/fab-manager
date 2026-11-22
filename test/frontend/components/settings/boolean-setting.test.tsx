import { BooleanSetting } from 'components/settings/boolean-setting';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';

describe('BooleanSetting', () => {
  test('toggles the switch when its label is clicked', async () => {
    const label = 'Enable the Family Account option';
    const onChange = jest.fn();
    render(<BooleanSetting name="family_account" label={label} onChange={onChange} onSuccess={jest.fn()} onError={jest.fn()} />);

    await waitFor(() => expect(onChange).toHaveBeenCalledWith('false'));
    const toggle = screen.getByRole('switch');
    expect(toggle).not.toBeChecked();

    fireEvent.click(screen.getByText(label));

    expect(toggle).toBeChecked();
    expect(onChange).toHaveBeenLastCalledWith('true');
    expect(screen.getByRole('switch', { name: label })).toBe(toggle);
  });
});
