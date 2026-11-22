# frozen_string_literal: true

require 'test_helper'

class StatisticCustomAggregationTest < ActiveSupport::TestCase
  test 'recognizes monetary metrics on stats revenue' do
    %w[avg sum min max].each do |operation|
      custom = StatisticCustomAggregation.new(es_index: 'stats', query: {
        aggregations: { '%<aggs_name>s' => { operation => { field: 'ca' } } }
      }.to_json)
      assert_equal 'currency', custom.data_type
    end
  end

  test 'recognizes monetary metrics stored with the legacy aggregation name placeholder' do
    assert_equal 'currency', statistic_custom_aggregations(:three).data_type
  end

  test 'keeps counts and non-monetary metrics numeric' do
    [{ avg: { field: 'age' } }, { value_count: { field: 'ca' } }, { cardinality: { field: 'ca' } }].each do |metric|
      custom = StatisticCustomAggregation.new(es_index: 'stats', query: { aggregations: { '%<aggs_name>s' => metric } }.to_json)
      assert_equal 'number', custom.data_type
    end
    custom = StatisticCustomAggregation.new(es_index: 'fablab', query: {
      aggregations: { '%<aggs_name>s' => { avg: { field: 'ca' } } }
    }.to_json)
    assert_equal 'number', custom.data_type
  end

  test 'defaults to numeric for missing or invalid query metadata' do
    [nil, '', '{}', 'invalid'].each do |query|
      assert_equal 'number', StatisticCustomAggregation.new(es_index: 'stats', query: query).data_type
    end
  end
end
