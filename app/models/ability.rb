class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :update, :destroy, :to => :modify
    user ||= User.new

    can :read, NewsItem

    return unless user.role? :member

    return unless user.role? :reporter

    can [:read, :create], Upload
    can :modify, Upload, :user_id => user.id

    can :read, [Tournament, Player, Result]
    can :modify, Tournament, :user_id => user.id
    can :modify, Player, :tournament => { :user_id => user.id }
    can :modify, Result, :player => { :tournament => { :user_id => user.id } }

    can :create, NewsItem
    can :modify, NewsItem, :user_id => user.id

    can :read, [IcuPlayer, FidePlayer, OldTournament, OldRatingHistory]

    return unless user.role? :officer

    can :read, Event
    can :manage, [Upload, Tournament, NewsItem]

    return unless user.role? :admin

    can :manage, :all
  end
end
