# frozen_string_literal: true

module Cloudtasker
  # Holds cloudtasker configuration. See Cloudtasker#configure
  class Config
    attr_writer :secret, :gcp_location_id, :gcp_project_id,
                :gcp_queue_id, :processor_host, :processor_path

    DEFAULT_LOCATION_ID = 'us-east1'
    DEFAULT_PROCESSOR_PATH = '/cloudtasker/run'

    PROCESSOR_HOST_MISSING = <<~DOC
      Missing host for processing.
      Please specify a processor hostname in form of `https://some-public-dns.example.com`'
    DOC
    QUEUE_ID_MISSING_ERROR = <<~DOC
      Missing GCP queue ID.
      Please specify a queue ID in the form of `my-queue-id`. You can create a queue using the Google SDK via `gcloud tasks queues create my-queue-id`
    DOC
    PROJECT_ID_MISSING_ERROR = <<~DOC
      Missing GCP project ID.
      Please specify a project ID in the cloudtasker configurator.
    DOC
    SECRET_MISSING_ERROR = <<~DOC
      Missing cloudtasker secret.
      Please specify a secret in the cloudtasker initializer or add Rails secret_key_base in your credentials
    DOC

    #
    # Return the full URL of the processor. Worker payloads will be sent
    # to this URL.
    #
    # @return [String] The processor URL.
    #
    def processor_url
      File.join(processor_host, processor_path)
    end

    #
    # The hostname of the application processing the workers. The hostname must
    # be reachable from Cloud Task.
    #
    # @return [String] The processor host.
    #
    def processor_host
      @processor_host || raise(StandardError, PROCESSOR_HOST_MISSING)
    end

    #
    # The path on the host when worker payloads will be sent.
    # Default to `/cloudtasker/run`
    #
    #
    # @return [String] The processor path
    #
    def processor_path
      @processor_path || DEFAULT_PROCESSOR_PATH
    end

    #
    # Return the ID of GCP queue where tasks will be added.
    #
    # @return [String] The ID of the processing queue.
    #
    def gcp_queue_id
      @gcp_queue_id || raise(StandardError, QUEUE_ID_MISSING_ERROR)
    end

    #
    # Return the GCP project ID.
    #
    # @return [String] The ID of the project for which tasks will be processed.
    #
    def gcp_project_id
      @gcp_project_id || raise(StandardError, PROJECT_ID_MISSING_ERROR)
    end

    #
    # Return the GCP location ID. Default to 'us-east1'
    #
    # @return [String] The location ID where tasks will be processed.
    #
    def gcp_location_id
      @gcp_location_id || DEFAULT_LOCATION_ID
    end

    #
    # Return the secret to use to sign the verification tokens
    # attached to tasks.
    #
    # @return [String] The cloudtasker secret
    #
    def secret
      @secret || (
        defined?(Rails) && Rails.application.credentials&.secret_key_base
      ) || raise(StandardError, SECRET_MISSING_ERROR)
    end
  end
end
