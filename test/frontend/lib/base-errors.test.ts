import apiClient from '../../../app/frontend/src/javascript/api/clients/api-client';

describe('API base errors', () => {
  test.each([
    [{ base: ['Password is too weak: minimum 12 characters'] }, 'Password is too weak: minimum 12 characters'],
    [{ password: ['is invalid'] }, 'password : is invalid'],
    [{ base: [] }, ''],
    [{ error: 'Unexpected error' }, 'Unexpected error']
  ])('renders %j without treating base as an attribute', async (data, expected) => {
    await expect(apiClient.get('/test-base-errors', {
      adapter: () => Promise.reject({ response: { data } })
    })).rejects.toBe(expected);
  });
});
