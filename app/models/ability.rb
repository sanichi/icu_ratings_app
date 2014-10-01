class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :update, :destroy, to: :modify
    user ||= User.new

    can :read, Article
    can :graph, IcuPlayer

    return unless user.role? :member

    can :show, IcuPlayer, id: user.icu_id
    can :show, Player
    can :my_home, Pages::MyHome

    return unless user.role? :reporter

    can [:read, :create], Upload
    can :modify, Upload, user_id: user.id
    can :read, [Download, Player, Result, Tournament]
    can :read, [FidePlayer, IcuPlayer, OldRatingHistory, OldTournament, OldRating]
    can :overview, Pages::Overview
    can :their_home, Pages::MyHome
    can_if_unlocked(user.id)

    return unless user.role? :officer

    can :read, [Event, Subscription]
    can [:read, :create], Publication
    can [:read, :create, :destroy], RatingRun
    can :manage, [Article, Download, Fee, FidePlayer, FidePlayerFile, Player, RatingList, Result, Tournament, Upload]
    cannot_if_locked

    return unless user.role? :admin

    can :manage, :all
    cannot_if_locked
  end

  def can_if_unlocked(user_id)
    can :modify, Tournament, user_id: user_id, locked: false
    can :modify, Player, tournament: { user_id: user_id, tournament: { locked: false } }
    can :modify, Result, player: { tournament: { user_id: user_id, locked: false } }
  end

  def cannot_if_locked
    cannot :modify, Tournament, locked: true
    cannot :modify, Player, tournament: { locked: true }
    cannot :modify, Result, player: { tournament: { locked: true } }
  end
end
