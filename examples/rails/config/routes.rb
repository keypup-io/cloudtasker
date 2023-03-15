# frozen_string_literal: true

Rails.application.routes.draw do
  get '/enqueue/dummy', to: 'enqueue_job#dummy'
end
