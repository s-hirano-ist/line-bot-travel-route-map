# frozen_string_literal: true

Rails.application.routes.draw do
  resources :widgets

  root "welcome#index"

  # for LINE webhook
  post "/callback" => "webhook#callback"
end
