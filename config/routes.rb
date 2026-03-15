Rails.application.routes.draw do
  root "kiosk#attract"

  get "enter", to: "kiosk#new"
  post "enter", to: "kiosk#create"
  get "success", to: "kiosk#success"

  get "up" => "rails/health#show", as: :rails_health_check
end
