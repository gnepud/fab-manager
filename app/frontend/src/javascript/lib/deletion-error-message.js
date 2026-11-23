export function deletionErrorMessage (error, fallback) {
  if (Array.isArray(error.data)) {
    const messages = error.data.filter(message => typeof message === 'string' && message.trim());
    if (messages.length) return messages.join(' ');
  }
  return fallback;
}
