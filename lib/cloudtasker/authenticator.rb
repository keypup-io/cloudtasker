# frozen_string_literal: true

require 'openssl'

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
    # The Authorization header content
    #
    # @return [String] The Bearer authorization header
    #
    def bearer_token
      "Bearer #{verification_token}"
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

    #
    # Generate a signature for a payload
    #
    # @param [String] payload The JSON payload
    #
    # @return [String] The HMAC signature
    #
    def sign_payload(payload)
      OpenSSL::HMAC.hexdigest('sha256', config.secret, payload)
    end

    #
    # Verify that a signature matches the payload and raise a `Cloudtasker::AuthenticationError`
    # if the signature is invalid.
    #
    # @param [String] signature The tested signature
    # @param [String] payload The JSON payload
    #
    # @return [Boolean] Return true if the signature is valid
    #
    def verify_signature!(signature, payload)
      ActiveSupport::SecurityUtils.secure_compare(signature, sign_payload(payload)) || raise(AuthenticationError)
    end
  end
end
