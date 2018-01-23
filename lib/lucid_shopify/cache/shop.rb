# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'lucid_shopify/cache/cache'
require 'lucid_shopify/cache/errors'

module LucidShopify
  module Cache
    class Shop
      #
      # @param myshopify_domain [String]
      # @param access_token [String]
      # @param redis_client [Redis]
      #
      def initialize(myshopify_domain, access_token, redis_client: nil)
        @myshopify_domain = myshopify_domain
        @access_token = access_token
        @redis_client = redis_client || defined?(Redis) && Redis.current
      end

      # @return [String]
      attr_reader :myshopify_domain
      # @return [String]
      attr_reader :access_token
      # @return [Redis]
      attr_reader :redis_client

      #
      # Get shop attributes hash from API or cache.
      #
      # @return [Hash]
      #
      # @raise [LucidShopify::Cache::RequestError] if the response status >= 400
      #
      def attributes
        @attributes ||=

        cache.('attributes') { api_attributes }.freeze
      end

      #
      # Get shop attributes hash from API after clearing cache (always get the
      # most up to date data). Use this when accuracy is important.
      #
      # @return [Hash]
      #
      # @raise [LucidShopify::Cache::RequestError] if the response status >= 400
      #
      def attributes!
        clear

        attributes
      end

      private def cache
        @cache ||=

        Cache.new('shops:%s' % myshopify_domain, redis_client: redis_client)
      end

      private def api_attributes
        uri = URI('https://%s/admin/shop.json' % myshopify_domain)

        req = Net::HTTP::Get.new(uri)
        req['Accept'] = 'application/json'
        req['X-Shopify-Access-Token'] = access_token
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }

        status = res.code.to_i

        if status != 200
          raise LucidShopify::Cache::RequestError.new(status), 'invalid response code %s' % status
        end

        api_attributes_parse(res.body)
      end

      private def api_attributes_parse(body)
        JSON.parse(body)['shop']
      end

      #
      # Clear the attributes cache.
      #
      def clear
        @attributes = nil

        cache.clear('attributes')
      end
    end
  end
end
