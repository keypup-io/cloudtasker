# frozen_string_literal: true

Cloudtasker::Engine.routes.draw do
  post '/run', to: 'worker#run'
end
