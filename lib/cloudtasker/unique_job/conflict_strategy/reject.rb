# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module ConflictStrategy
      # This strategy rejects the job on conflict. This is equivalent to "do nothing".
      class Reject < BaseStrategy
      end
    end
  end
end
