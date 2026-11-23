const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const localesDirectory = path.resolve(__dirname, '../../../config/locales');

describe('bank transfer payment schedule labels', () => {
  test.each([
    ['fr', 'par virement', 'En attente de la confirmation du virement'],
    ['it', 'con bonifico bancario', 'In attesa conferma del bonifico bancario']
  ])('%s identifies bank transfers rather than direct debits', (locale, paidMethod, pendingState) => {
    const translations = yaml.load(fs.readFileSync(path.join(localesDirectory, `app.shared.${locale}.yml`), 'utf8'));
    const labels = translations[locale].app.shared.payment_schedules_table;

    expect(labels.method_transfer).toBe(paidMethod);
    expect(labels.state_pending_transfer).toBe(pendingState);
  });
});
