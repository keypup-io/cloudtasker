# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Middleware
      # Client middleware, invoked when jobs are scheduled
      class Client
        def call(worker)
          Job.new(worker).lock_instance.schedule { yield }
        end
      end
    end
  end
end
