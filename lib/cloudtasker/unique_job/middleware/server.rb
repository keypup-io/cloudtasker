# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Middleware
      # Server middleware, invoked when jobs are executed
      class Server
        def call(worker)
          Job.new(worker).lock_instance.execute { yield }
        end
      end
    end
  end
end
