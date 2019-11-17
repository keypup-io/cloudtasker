# frozen_string_literal: true

require 'cloudtasker/cron/middleware'

RSpec.describe Cloudtasker::Batch::Middleware do
  describe '.configure' do
    before { described_class.configure }

    it { expect(Cloudtasker.config.server_middleware).to be_exists(Cloudtasker::Batch::Middleware::Server) }
  end
end
