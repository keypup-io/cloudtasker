# frozen_string_literal: true

module Cloudtasker
  module Batch
    module Extension
      # Include batch related methods onto Cloudtasker::Worker
      # See: Cloudtasker::Batch::Middleware#configure
      module Worker
        attr_accessor :batch, :parent_batch
      end
    end
  end
end
