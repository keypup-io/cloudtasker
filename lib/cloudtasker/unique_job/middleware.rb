# frozen_string_literal: true

require 'cloudtasker/redis_client'

require_relative 'lock_error'
require_relative 'config'

require_relative 'conflict_strategy/base_strategy'
require_relative 'conflict_strategy/raise'
require_relative 'conflict_strategy/reject'
require_relative 'conflict_strategy/reschedule'

require_relative 'lock/base_lock'
require_relative 'lock/no_op'
require_relative 'lock/until_executed'
require_relative 'lock/until_executing'
require_relative 'lock/while_executing'

require_relative 'job'

require_relative 'middleware/client'

module Cloudtasker
  module UniqueJob
    # Registration module
    module Middleware
    end
  end
end
