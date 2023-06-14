# frozen_string_literal: true

module Cloudtasker
  module Batch
    module Middleware
      # Server middleware, invoked when jobs are executed
      class Server
        def call(worker, **_kwargs, &block)
          Job.for(worker).execute(&block)
        end
      end
    end
  end
end
