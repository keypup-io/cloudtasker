# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Lock
      # Equivalent to no lock
      class NoOp < BaseLock
      end
    end
  end
end
