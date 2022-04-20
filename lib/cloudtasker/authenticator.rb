# frozen_string_literal: true

module Cloudtasker
  # Manage token generation and verification
  module Authenticator
    module_function

    # Algorithm used to sign the verification token
    JWT_ALG = 'HS256'

    #
    # Return the cloudtasker configuration. See Cloudtasker#configure.
    #
    # @return [Cloudtasker::Config] The library configuration.
    #
    def config
      Cloudtasker.config
    end

    #
    # A Json Web Token (JWT) which will be used by the processor
    # to authenticate the job.
    #
    # @return [String] The jwt token
    #
    def verification_token
      return oidc_token if config.oidc_enabled

      JWT.encode({ iat: Time.now.to_i }, config.secret, JWT_ALG)
    end

    #
    # Verify a bearer token (jwt token)
    #
    # @param [String] bearer_token The token to verify.
    #
    # @return [Boolean] Return true if the token is valid
    #
    def verify(bearer_token)
      JWT.decode(bearer_token, config.secret)
    rescue JWT::VerificationError, JWT::DecodeError
      false
    end

    #
    # Verify a bearer token and raise a `Cloudtasker::AuthenticationError`
    # if the token is invalid.
    #
    # @param [String] bearer_token The token to verify.
    #
    # @return [Boolean] Return true if the token is valid
    #
    def verify!(bearer_token)
      verify(bearer_token) || raise(AuthenticationError)
    end
    
    def oidc_token
      google_metadata_server_url = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity'

      res = Faraday.get(google_metadata_server_url, { audience: config.processor_host }, { 'Metadata-Flavor' => 'Google' })

      raise(StandardError,OIDC_FETCH_ERROR) if res.status >= 400

      res.body.to_s
    end
    
  end
end
