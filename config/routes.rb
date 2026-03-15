Rails.application.routes.draw do
  root "kiosk#attract"

  get "enter", to: "kiosk#new"
  post "enter", to: "kiosk#create"
  get "success", to: "kiosk#success"

  namespace :admin do
    root "entries#index"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :entries, only: [ :index, :show ] do
      member do
        patch :exclude
        patch :reinstate
      end
    end

    get "export", to: "exports#index", as: :export
    get "export/download", to: "exports#download", as: :export_download
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
