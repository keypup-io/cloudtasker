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
  end
end
