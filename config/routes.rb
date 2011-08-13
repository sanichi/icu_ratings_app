Ratings::Application.routes.draw do

  root :to => "pages#home"

  get "home"     => "pages#home"
  get "contacts" => "pages#contacts"
  get "log_in"   => "sessions#new"
  get "log_out"  => "sessions#destroy"

  resources :sessions,     :only => [:create]
  resources :tournaments,  :only => [:index, :show]
  resources :icu_players,  :only => [:index, :show]
  resources :fide_players, :only => [:index, :show]
  resources :news_items

  namespace "admin" do
    resources :events,               :only => [:index, :show, :destroy]
    resources :uploads,              :only => [:index, :show, :new, :create, :destroy]
    resources :tournaments,          :only => [:index, :show, :edit, :update]
    resources :players,              :only => [:index, :show, :edit, :update]
    resources :results,              :only => [:new, :create, :edit, :update]
    resources :users,                :only => [:index, :show, :edit, :update]
    resources :logins,               :only => [:index]
    resources :old_tournaments,      :only => [:index]
    resources :old_rating_histories, :only => [:index]
  end
  
  match "*url" => "pages#not_found"
end
