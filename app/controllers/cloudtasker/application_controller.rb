# frozen_string_literal: true

module Cloudtasker
  # Base Cloudtasker controller
  class ApplicationController < ActionController::Base
    skip_before_action :verify_authenticity_token
  end
end
