# frozen_string_literal: true

require 'sinatra'

# Require project files
Dir.glob('./config/initializers/*.rb').each { |file| require file }
Dir.glob('./app/workers/*.rb').each { |file| require file }

#---------------------------------------------------
# Routes
#---------------------------------------------------

get '/' do
  'Hello!'
end

post '/cloudtasker/run' do
  begin
    # Authenticate request
    Cloudtasker::Authenticator.verify!(request.env['HTTP_AUTHORIZATION'].to_s.split(' ').last)

    # Capture content and decode content
    content = request.body.read
    content = Base64.decode64(content) if request.env['HTTP_CONTENT_TRANSFER_ENCODING'].to_s.downcase == 'base64'

    # Format job payload
    payload = JSON.parse(content)
                  .merge(job_retries: request.env['HTTP_X_CLOUDTASKS_TASKEXECUTIONCOUNT'].to_i)

    # Process payload
    Cloudtasker::WorkerHandler.execute_from_payload!(payload)
    return 204
  rescue Cloudtasker::DeadWorkerError
    # 205: job will NOT be retried
    return 205
  rescue Cloudtasker::AuthenticationError
    # 401: Unauthorized
    return 401
  rescue Cloudtasker::InvalidWorkerError
    # 404: Job will be retried
    return 404
  rescue StandardError => e
    # 404: Job will be retried
    Cloudtasker.logger.error(e)
    Cloudtasker.logger.error(e.backtrace.join("\n"))
    head :unprocessable_entity
  end
end
