# frozen_string_literal: true

# Synthetic fixtures for the browser regression cases in this directory.
class BrowserQaSeed
  def run
    abort 'Browser QA seed requires an isolated development database.' unless Rails.env.development?
    abort 'Run db:seed before the browser QA seed.' unless User.admins.exists? && StatisticIndex.exists?
    abort 'Disable online payment before seeding browser QA data.' if Setting.get('online_payment_module')

    password = ENV.fetch('BROWSER_QA_PASSWORD')
    day = Time.zone.tomorrow + 1
    availability_ids = ApplicationRecord.transaction do
      enable_modules
      group = Group.find_or_create_by!(name: 'QA Browser', slug: 'qa-browser')
      other_group = Group.find_or_create_by!(name: 'QA Browser Other', slug: 'qa-browser-other')
      member = seed_users(group, other_group, password)
      resources = seed_resources(group, other_group, day)
      events = seed_events(day)
      seed_catalog(member)
      resources + events
    end
    index_availabilities(availability_ids)
    puts 'Browser QA ready: 7 accounts, 2 groups, 2 machines, 1 training, 1 space, 1 plan, 1 pack, 2 events, 1 product, 1 project.'
    puts "Machine, training and space availability begins #{day.iso8601} (#{Time.zone.name})."
  end

  private

  def enable_modules
    %w[spaces_module store_module].each do |name|
      Setting.set(name, true).save! unless Setting.get(name)
    end
    Setting.set('store_hidden', false).save! unless Setting.get('store_hidden') == false
  end

  def index_availabilities(ids)
    worker = AvailabilityIndexerWorker.new
    ids.each { |id| worker.perform('index', id) }
    AvailabilityIndexerWorker::Client.indices.refresh(index: Availability.index_name)
  end

  def seed_users(group, other_group, password)
    {
      'admin' => :admin, 'manager' => :manager, 'member' => :member, 'member2' => :member,
      'other' => :member, 'partner' => :partner, 'delete' => :member
    }.each_with_object({}) do |(name, role), users|
      users[name] = User.find_or_create_by!(email: "qa-#{name}@example.com") do |user|
        user.assign_attributes(username: "qa-#{name}", password: password, password_confirmation: password,
                               group: name == 'other' ? other_group : group,
                               profile_attributes: { first_name: 'QA', last_name: name.capitalize, phone: '0123456789' },
                               statistic_profile_attributes: { gender: true, birthday: Date.new(1990, 1, 1) })
        user.add_role(role)
        user.skip_confirmation!
      end
    end.fetch('member')
  end

  def seed_resources(group, other_group, day)
    training = Training.find_or_create_by!(name: 'QA Training') { |item| item.description = 'Browser QA training' }
    machine = Machine.find_or_create_by!(name: 'QA Machine') do |item|
      item.description = 'Browser QA machine requiring QA Training'
      item.trainings = [training]
    end
    open_machine = Machine.find_or_create_by!(name: 'QA Open Machine') { |item| item.description = 'Browser QA open machine' }
    space = Space.find_or_create_by!(name: 'QA Space') { |item| item.default_places = 4 }
    seed_prices(group, other_group, [machine, open_machine, space], training)
    seed_plan(group, machine, training)
    (0...3).flat_map do |offset|
      date = day + offset
      [
        seed_availability(machine, date, 10, 'machines', machines: [machine, open_machine], slot_duration: 60),
        seed_availability(training, date, 13, 'training', trainings: [training], nb_total_places: 4),
        seed_availability(space, date, 15, 'space', spaces: [space], nb_total_places: 4, slot_duration: 60)
      ]
    end
  end

  def seed_prices(group, other_group, resources, training)
    resources.each do |resource|
      [[group, 1_000], [other_group, 1_500]].each do |price_group, amount|
        price = Price.find_or_initialize_by(priceable: resource, group: price_group, plan: nil)
        price.update!(amount: amount) if price.new_record? || price.amount.zero?
      end
    end
    pricing = TrainingsPricing.find_by!(group: group, training: training)
    pricing.update!(amount: 2_500) if pricing.amount.zero?
  end

  def seed_plan(group, machine, training)
    plan = Plan.find_or_create_by!(base_name: 'QA Plan', group: group) do |item|
      item.assign_attributes(interval: 'month', interval_count: 3, amount: 3_600, training_credit_nb: 2)
    end
    plan.credits.find_or_create_by!(creditable: machine) { |credit| credit.hours = 2 }
    plan.credits.find_or_create_by!(creditable: training)
    machine.prepaid_packs.find_or_create_by!(group: group, minutes: 180) do |pack|
      pack.assign_attributes(amount: 2_400, validity_interval: 'month', validity_count: 1, disabled: false)
    end
  end

  def seed_availability(resource, date, hour, type, attributes)
    start_at = Time.zone.local(date.year, date.month, date.day, hour)
    times = { start_at: start_at, end_at: start_at + 2.hours, available_type: type }
    availability = resource.availabilities.find_by(times) || Availability.create!(times.merge(attributes))
    Availabilities::CreateAvailabilitiesService.new.create(availability, []) unless availability.slots.exists?
    availability.id
  end

  def seed_events(day)
    category = Category.find_or_create_by!(name: 'QA Events')
    fare = PriceCategory.find_or_create_by!(name: 'QA Reduced') { |price| price.conditions = 'Browser QA reduced fare' }
    {
      'QA Standard Event' => ['standard', 1_200, 11],
      'QA Family Event' => ['family', 0, 15]
    }.map do |title, (type, amount, hour)|
      event = Event.find_or_create_by!(title: title) do |item|
        start_at = Time.zone.local(day.year, day.month, day.day, hour)
        item.assign_attributes(description: 'Browser QA event', event_type: type, amount: amount, nb_total_places: 8,
                               category: category,
                               availability_attributes: { start_at: start_at, end_at: start_at + 1.hour, available_type: 'event' })
      end
      Availabilities::CreateAvailabilitiesService.new.create_slots(event.availability) unless event.availability.slots.exists?
      event.event_price_categories.find_or_create_by!(price_category: fare) { |price| price.amount = 600 } if type == 'standard'
      event.availability_id
    end
  end

  def seed_catalog(member)
    category = ProductCategory.find_or_create_by!(name: 'QA Stock')
    Product.find_or_create_by!(name: 'QA Product') do |product|
      product.assign_attributes(product_category: category, sku: 'QA-PRODUCT', is_active: true, amount: 1_200,
                                quantity_min: 1, stock: { external: 10, internal: 10 })
    end
    Project.find_or_create_by!(name: 'QA Browser Project', author: member.statistic_profile) do |project|
      project.assign_attributes(description: 'Browser QA project', state: 'published', licence: Licence.first)
    end
  end
end

BrowserQaSeed.new.run
