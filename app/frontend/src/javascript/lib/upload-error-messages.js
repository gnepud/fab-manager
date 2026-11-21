export function uploadErrorMessages (value) {
  return typeof value === 'string' ? [value] : value;
}
