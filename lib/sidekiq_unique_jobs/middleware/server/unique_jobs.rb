require 'digest'
require 'sidekiq_unique_jobs/connectors'

module SidekiqUniqueJobs
  module Middleware
    module Server
      class UniqueJobs
        attr_reader :unlock_order, :redis_pool

        def call(worker, item, _queue, redis_pool = nil)
          @redis_pool = redis_pool
          decide_unlock_order(worker.class)
          lock_key = item['unique_hash'] || payload_hash(item)
          unlock(lock_key) if before_yield?

          result = yield

          if after_yield?
            unlock(lock_key)
            after_unlock_hook(worker)
          end
          result
        end

        def decide_unlock_order(klass)
          @unlock_order = if unlock_order_configured?(klass)
                            klass.get_sidekiq_options['unique_unlock_order']
                          else
                            default_unlock_order
                          end
        end

        def unlock_order_configured?(klass)
          klass.respond_to?(:get_sidekiq_options) &&
            !klass.get_sidekiq_options['unique_unlock_order'].nil?
        end

        def default_unlock_order
          SidekiqUniqueJobs.config.default_unlock_order
        end

        def before_yield?
          unlock_order == :before_yield
        end

        def after_yield?
          unlock_order == :after_yield
        end

        protected

        def payload_hash(item)
          SidekiqUniqueJobs::PayloadHelper.get_payload(item['class'], item['queue'], item['args'])
        end

        def unlock(payload_hash)
          connection { |c| c.del(payload_hash) }
        end

        def after_unlock_hook(worker)
          # don't call after unlock hook at this point if you're testing in inline! mode
          unless Sidekiq.const_defined?('Testing') && Sidekiq::Testing.inline?
            if worker.respond_to?(:after_unlock)
              worker.after_unlock
            end
          end
        end

        def logger
          Sidekiq.logger
        end

        def connection(&block)
          SidekiqUniqueJobs::Connectors.connection(redis_pool, &block)
        end
      end
    end
  end
end
