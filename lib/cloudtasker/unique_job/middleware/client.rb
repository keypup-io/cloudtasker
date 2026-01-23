# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Middleware
      # Client middleware, invoked when jobs are scheduled
      class Client
        def call(worker, opts = {}, &block)
          Job.new(worker, opts).lock_instance.schedule(&block)
        end
      end
    end
  end
end
