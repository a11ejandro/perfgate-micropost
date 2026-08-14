Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "microposts#index"

  resources :microposts, only: %i[index show] do
    collection { get :search }
    resources :comments, only: %i[create]
  end
end
