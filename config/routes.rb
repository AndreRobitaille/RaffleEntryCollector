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
        get :company_matches
      end
    end

    get "export", to: "exports#index", as: :export
    get "export/download", to: "exports#download", as: :export_download

    resource :raffle, only: [ :show ], controller: "raffle" do
      post :draw
    end

    resource :management, only: [ :show ], controller: "management" do
      post :reset_drawing
      post :populate_demo
      post :clear_entrants
      post :factory_reset
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
