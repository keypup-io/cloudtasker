# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::Middleware do
  describe '.configure' do
    before { described_class.configure }

    it { expect(Cloudtasker.config.client_middleware).to exist(Cloudtasker::UniqueJob::Middleware::Client) }
    it { expect(Cloudtasker.config.server_middleware).to exist(Cloudtasker::UniqueJob::Middleware::Server) }
  end
end
