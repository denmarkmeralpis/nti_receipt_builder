# frozen_string_literal: true

Rails.application.routes.draw do
  resources :receipt_templates, except: [:show] do
    member do
      get :preview
      post :render_preview
      get :print
      patch :set_default
    end
  end
end
