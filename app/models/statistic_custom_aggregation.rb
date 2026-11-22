# frozen_string_literal: true

# StatisticCustomAggregation is an ElasticSearch aggregation that will run when the end-user is browsing the statistics
# page for the related StatisticType.
# See https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html
class StatisticCustomAggregation < ApplicationRecord
  belongs_to :statistic_type

  def data_type
    return 'number' unless es_index == 'stats'

    aggregations = JSON.parse(query.presence || '{}')['aggregations'] || {}
    monetary = aggregations.values.any? do |aggregation|
      %w[avg sum min max].any? { |operation| aggregation.dig(operation, 'field') == 'ca' }
    end
    monetary ? 'currency' : 'number'
  rescue JSON::ParserError
    'number'
  end
end
