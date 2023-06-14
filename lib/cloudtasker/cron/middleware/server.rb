# frozen_string_literal: true

module Cloudtasker
  module Cron
    module Middleware
      # Server middleware, invoked when jobs are executed
      class Server
        def call(worker, **_kwargs, &block)
          Job.new(worker).execute(&block)
        end
      end
    end
  end
end
