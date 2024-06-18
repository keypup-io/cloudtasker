# frozen_string_literal: true

require 'cloudtasker/cron/middleware'

RSpec.describe Cloudtasker::Cron::Middleware do
  describe '.configure' do
    before { described_class.configure }

    it { expect(Cloudtasker.config.server_middleware).to exist(Cloudtasker::Cron::Middleware::Server) }
  end
end
