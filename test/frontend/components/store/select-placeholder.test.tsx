import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { useForm } from 'react-hook-form';
import { FormSelect } from '../../../../app/frontend/src/javascript/components/form/form-select';
import { StoreListHeader } from '../../../../app/frontend/src/javascript/components/store/store-list-header';

const MachineSelect = ({ placeholder }: { placeholder?: string }) => {
  const { control, formState } = useForm<{ machine_id: number }>();
  return <FormSelect id="machine_id" options={[]} control={control} formState={formState} placeholder={placeholder} />;
};

describe('Select placeholders', () => {
  it('uses the shared translation for the machine selector', () => {
    render(<MachineSelect />);

    expect(screen.getByText('app.shared.fab_select.placeholder')).toBeInTheDocument();
  });

  it('uses the shared translation for the orders sort selector', () => {
    render(<StoreListHeader productsCount={0} selectOptions={[]} onSelectOptionsChange={jest.fn()} />);

    expect(screen.getByText('app.shared.fab_select.placeholder')).toBeInTheDocument();
  });

  it('keeps an explicit placeholder', () => {
    render(<MachineSelect placeholder="Custom placeholder" />);

    expect(screen.getByText('Custom placeholder')).toBeInTheDocument();
  });
});
