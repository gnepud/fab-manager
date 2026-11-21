import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import SupportingDocumentRefusalAPI from '../../../app/frontend/src/javascript/api/supporting-document-refusal';
import { SupportingDocumentsRefusalModal } from '../../../app/frontend/src/javascript/components/supporting-documents/supporting-documents-refusal-modal';
import { User } from '../../../app/frontend/src/javascript/models/user';
import { SupportingDocumentType } from '../../../app/frontend/src/javascript/models/supporting-document-type';

test('reopening the refusal dialog does not let an admin resend the previous refusal', async () => {
  const create = jest.spyOn(SupportingDocumentRefusalAPI, 'create').mockResolvedValue(undefined);
  try {
    const props = {
      toggleModal: jest.fn(),
      onSuccess: jest.fn(),
      onError: jest.fn(),
      operator: { id: 1 } as User,
      supportable: { id: 2 } as User,
      documentType: 'User' as const,
      proofOfIdentityTypes: [{ id: 3, name: 'Proof of identity', group_ids: [], document_type: 'User' }] as SupportingDocumentType[]
    };
    const { rerender } = render(<SupportingDocumentsRefusalModal {...props} isOpen={true} />);
    const getSendButton = () => screen.getByRole('button', {
      name: 'app.admin.supporting_documents_refusal_modal.confirm',
      hidden: true
    });
    const getComment = () => screen.getByLabelText('app.admin.supporting_documents_refusal_form.refusal_comment');
    const getDocument = () => screen.getByLabelText('Proof of identity');

    expect(getSendButton()).toBeDisabled();
    fireEvent.change(getComment(), { target: { value: 'Please send a clearer copy.' } });
    expect(getSendButton()).toBeDisabled();
    fireEvent.click(getDocument());
    expect(getSendButton()).toBeEnabled();
    fireEvent.click(getDocument());
    expect(getSendButton()).toBeDisabled();
    fireEvent.click(getDocument());
    fireEvent.click(getSendButton());
    await waitFor(() => expect(props.onSuccess).toHaveBeenCalledTimes(1));
    expect(create).toHaveBeenCalledWith({
      id: null,
      operator_id: 1,
      supportable_id: 2,
      supportable_type: 'User',
      supporting_document_type_ids: [3],
      message: 'Please send a clearer copy.'
    });

    rerender(<SupportingDocumentsRefusalModal {...props} isOpen={false} />);
    rerender(<SupportingDocumentsRefusalModal {...props} isOpen={true} />);

    expect(getDocument()).not.toBeChecked();
    expect(getComment()).toHaveValue('');
    fireEvent.click(getSendButton());
    expect(getSendButton()).toBeDisabled();
    expect(create).toHaveBeenCalledTimes(1);
  } finally {
    create.mockRestore();
  }
});
