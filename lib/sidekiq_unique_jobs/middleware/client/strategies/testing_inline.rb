require 'sidekiq_unique_jobs/middleware/server/unique_jobs'

module SidekiqUniqueJobs
  module Middleware
    module Client
      module Strategies
        class TestingInline < Unique
          # Patch - disable TestingInline because it calls server middleware from the client side
          # and so jobs are unlocked and after_unlock is called before the job is executed
          # Expected execution behavior with server_middleware has been patched within sidekiq_test_overrides
          def self.elegible?
            # SidekiqUniqueJobs.config.inline_testing_enabled?
            false
          end

          def review
            _middleware.call(worker_class.new, item, queue, redis_pool) do
              super
            end
          end

          def _middleware
            SidekiqUniqueJobs::Middleware::Server::UniqueJobs.new
          end
        end
      end
    end
  end
end
