const { TestEnvironment } = require('jest-environment-jsdom');

// jsdom environment where a test can switch the local time zone with setTimezone('Europe/Paris')
class TimezoneEnvironment extends TestEnvironment {
  constructor (config, context) {
    super(config, context);
    this.initialTimezone = process.env.TZ;
    this.global.setTimezone = timezone => { process.env.TZ = timezone; };
  }

  async teardown () {
    if (this.initialTimezone === undefined) {
      delete process.env.TZ;
    } else {
      process.env.TZ = this.initialTimezone;
    }
    await super.teardown();
  }
}

module.exports = TimezoneEnvironment;
