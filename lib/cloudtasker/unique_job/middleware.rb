# frozen_string_literal: true

require 'cloudtasker/redis_client'

require_relative 'lock_error'
require_relative 'config'
require_relative 'job'

require_relative 'middleware/client'

require_relative 'lock/base_lock'
require_relative 'lock/no_op'
require_relative 'lock/until_executed'

module Cloudtasker
  module UniqueJob
    # Registration module
    module Middleware
    end
  end
end
