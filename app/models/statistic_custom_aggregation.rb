# frozen_string_literal: true

# StatisticCustomAggregation is an ElasticSearch aggregation that will run when the end-user is browsing the statistics
# page for the related StatisticType.
# See https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html
class StatisticCustomAggregation < ApplicationRecord
  belongs_to :statistic_type

  def data_type
    return 'number' unless es_index == 'stats'

    aggregation = JSON.parse(query.presence || '{}').dig('aggregations', '%<aggs_name>s') || {}
    monetary = %w[avg sum min max].any? { |operation| aggregation.dig(operation, 'field') == 'ca' }
    monetary ? 'currency' : 'number'
  rescue JSON::ParserError
    'number'
  end
end
