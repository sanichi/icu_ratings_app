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

    can :read, [Download, Player, Result, Tournament]
    can :modify, Tournament, :user_id => user.id
    can :modify, Player, :tournament => { :user_id => user.id }
    can :modify, Result, :player => { :tournament => { :user_id => user.id } }

    can :create, NewsItem
    can :modify, NewsItem, :user_id => user.id

    can :read, [FidePlayer, IcuPlayer, OldRatingHistory, OldTournament]

    return unless user.role? :officer

    can :read, Event
    can :manage, [Download, NewsItem, Tournament, Upload]

    return unless user.role? :admin

    can :manage, :all
  end
end
