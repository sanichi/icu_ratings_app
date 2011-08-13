class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :update, :destroy, :to => :modify
    user ||= User.new
    
    # What anyone can do.
    can :read, NewsItem
    
    # What members can do.
    return unless user.role? :member

    # What tournament reporters can do.
    return unless user.role? :reporter
    can :manage, Upload
    can :manage, Tournament
    can :manage, Player
    can :manage, Result
    can :create, NewsItem
    can :modify, NewsItem, :user_id => user.id
    can :read, IcuPlayer
    can :read, FidePlayer
    can :read, OldTournament
    can :read, OldRatingHistory
    
    # What rating officers can do.
    return unless user.role? :officer
    can :read, Event
    can :manage, NewsItem
    
    # What administrators can do.
    return unless user.role? :admin
    can :manage, :all
  end
end
