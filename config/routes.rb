Ratings::Application.routes.draw do

  root to: "pages#home"

  %w[home contacts overview].each { |p| get p => "pages##{p}"}
  get "log_in"  => "sessions#new"
  get "log_out" => "sessions#destroy"

  resources :downloads
  resources :federations,  only: [:index]
  resources :fide_players, only: [:index, :show, :update]
  resources :fide_ratings, only: [:index, :show]
  resources :icu_players,  only: [:index, :show] do
    get :graph, on: :member
  end
  resources :icu_ratings,  only: [:index, :show] do
    get :war, :juniors, :improvers, on: :collection
  end
  resources :news_items
  resources :sessions,     only: [:create]
  resources :tournaments,  only: [:index, :show]

  namespace "admin" do
    resources :events,               only: [:index, :show, :destroy]
    resources :failures,             only: [:index, :show, :destroy, :new]
    resources :logins,               only: [:index]
    resources :old_ratings,          only: [:index]
    resources :old_rating_histories, only: [:index]
    resources :old_tournaments,      only: [:index]
    resources :players,              only: [:show, :edit, :update]
    resources :results,              only: [:new, :create, :edit, :update]
    resources :tournaments,          only: [:index, :show, :edit, :update, :destroy]
    resources :uploads,              only: [:index, :show, :new, :create, :destroy]
    resources :users,                only: [:index, :show, :edit, :update]
  end

  match "*url" => "pages#not_found"
end
