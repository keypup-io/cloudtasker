# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Middleware
      # Server middleware, invoked when jobs are executed
      class Server
        def call(worker, **_kwargs, &block)
          Job.new(worker).lock_instance.execute(&block)
        end
      end
    end
  end
end
