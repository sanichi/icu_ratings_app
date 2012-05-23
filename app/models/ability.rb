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

    return unless user.role? :reporter

    can [:read, :create], Upload
    can :modify, Upload, user_id: user.id

    can :read, [Download, Player, Result, Tournament]
    can :modify, Tournament, user_id: user.id, locked: false
    can :modify, Player, tournament: { user_id: user.id, tournament: { locked: false } }
    can :modify, Result, player: { tournament: { user_id: user.id, locked: false } }

    can :create, Article
    can :modify, Article, user_id: user.id

    can :read, [FidePlayer, IcuPlayer, OldRatingHistory, OldTournament, OldRating]
    
    can :overview, Pages::Overview

    return unless user.role? :officer

    can :read, Event
    can [:read, :create, :destroy], RatingRun
    can :manage, [Download, FidePlayer, Article, Tournament, Player, Result, Upload]
    cannot :modify, Tournament, locked: true
    cannot :modify, Player, tournament: { locked: true }
    cannot :modify, Result, player: { tournament: { locked: true } }

    return unless user.role? :admin

    can :manage, :all
    cannot :modify, Tournament, locked: true
    cannot :modify, Player, tournament: { locked: true }
    cannot :modify, Result, player: { tournament: { locked: true } }
  end
end
