# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130403204420) do

  create_table "articles", :force => true do |t|
    t.string   "headline"
    t.text     "story"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "published",  :default => false
    t.string   "identity"
  end

  add_index "articles", ["published"], :name => "index_articles_on_published"
  add_index "articles", ["user_id"], :name => "index_articles_on_user_id"

  create_table "downloads", :force => true do |t|
    t.string   "comment"
    t.string   "file_name"
    t.string   "content_type"
    t.binary   "data",         :limit => 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "events", :force => true do |t|
    t.string   "name"
    t.integer  "time",       :limit => 2
    t.text     "report"
    t.boolean  "success"
    t.datetime "created_at"
  end

  create_table "failures", :force => true do |t|
    t.string   "name"
    t.text     "details"
    t.datetime "created_at"
  end

  create_table "fees", :force => true do |t|
    t.string   "description"
    t.string   "status",      :limit => 25
    t.string   "category",    :limit => 3
    t.date     "date"
    t.integer  "icu_id"
    t.boolean  "used",                      :default => false
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
  end

  create_table "fide_player_files", :force => true do |t|
    t.text     "description"
    t.integer  "players_in_file",  :limit => 2, :default => 0
    t.integer  "new_fide_records", :limit => 1, :default => 0
    t.integer  "new_icu_mappings", :limit => 1, :default => 0
    t.integer  "user_id"
    t.datetime "created_at"
  end

  create_table "fide_players", :force => true do |t|
    t.string   "last_name"
    t.string   "first_name"
    t.string   "fed",        :limit => 3
    t.string   "title",      :limit => 3
    t.string   "gender",     :limit => 1
    t.integer  "born",       :limit => 2
    t.integer  "rating",     :limit => 2
    t.integer  "icu_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "fide_players", ["icu_id"], :name => "index_fide_players_on_icu_id"
  add_index "fide_players", ["last_name", "first_name"], :name => "index_fide_players_on_last_name_and_first_name"

  create_table "fide_ratings", :force => true do |t|
    t.integer  "fide_id"
    t.integer  "rating",     :limit => 2
    t.integer  "games",      :limit => 2
    t.date     "list"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "fide_ratings", ["fide_id"], :name => "index_fide_ratings_on_fide_id"
  add_index "fide_ratings", ["list"], :name => "index_fide_ratings_on_list"

  create_table "icu_players", :force => true do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.string   "club"
    t.string   "address"
    t.string   "phone_numbers"
    t.string   "fed",           :limit => 3
    t.string   "title",         :limit => 3
    t.string   "gender",        :limit => 1
    t.text     "note"
    t.date     "dob"
    t.date     "joined"
    t.boolean  "deceased"
    t.integer  "master_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "icu_players", ["last_name", "first_name"], :name => "index_icu_players_on_last_name_and_first_name"

  create_table "icu_ratings", :force => true do |t|
    t.date    "list"
    t.integer "icu_id"
    t.integer "rating",          :limit => 2
    t.boolean "full",                         :default => false
    t.integer "original_rating", :limit => 2
    t.boolean "original_full"
  end

  add_index "icu_ratings", ["icu_id"], :name => "index_icu_ratings_on_icu_id"
  add_index "icu_ratings", ["list", "icu_id"], :name => "index_icu_ratings_on_list_and_icu_id", :unique => true
  add_index "icu_ratings", ["list"], :name => "index_icu_ratings_on_list"

  create_table "logins", :force => true do |t|
    t.integer  "user_id"
    t.string   "ip",         :limit => 39
    t.string   "problem",    :limit => 8,  :default => "none"
    t.string   "role",       :limit => 20
    t.datetime "created_at"
  end

  create_table "old_players", :force => true do |t|
    t.integer  "icu_id"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "club"
    t.string   "gender",     :limit => 1
    t.date     "dob"
    t.date     "joined"
    t.text     "note"
    t.integer  "rating",     :limit => 2
    t.integer  "events",     :limit => 2
    t.integer  "games",      :limit => 2
    t.string   "status",     :limit => 20, :default => "archived"
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
  end

  create_table "old_rating_histories", :force => true do |t|
    t.integer "old_tournament_id"
    t.integer "icu_player_id"
    t.integer "old_rating",         :limit => 2
    t.integer "new_rating",         :limit => 2
    t.integer "performance_rating", :limit => 2
    t.integer "tournament_rating",  :limit => 2
    t.integer "bonus",              :limit => 2
    t.integer "games",              :limit => 1
    t.integer "kfactor",            :limit => 1
    t.decimal "actual_score",                    :precision => 3, :scale => 1
    t.decimal "expected_score",                  :precision => 8, :scale => 6
  end

  add_index "old_rating_histories", ["icu_player_id"], :name => "index_old_rating_histories_on_icu_player_id"
  add_index "old_rating_histories", ["old_tournament_id", "icu_player_id"], :name => "by_icu_player_old_tournament", :unique => true
  add_index "old_rating_histories", ["old_tournament_id"], :name => "index_old_rating_histories_on_old_tournament_id"

  create_table "old_ratings", :force => true do |t|
    t.integer "icu_id"
    t.integer "rating", :limit => 2
    t.integer "games",  :limit => 2
    t.boolean "full",                :default => false
  end

  add_index "old_ratings", ["icu_id"], :name => "index_old_ratings_on_icu_id", :unique => true

  create_table "old_tournaments", :force => true do |t|
    t.string  "name"
    t.date    "date"
    t.integer "player_count", :limit => 2
  end

  create_table "players", :force => true do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.string   "fed",                   :limit => 3
    t.string   "title",                 :limit => 3
    t.string   "gender",                :limit => 1
    t.integer  "icu_id"
    t.integer  "fide_id"
    t.integer  "icu_rating",            :limit => 2
    t.integer  "fide_rating",           :limit => 2
    t.date     "dob"
    t.string   "status"
    t.string   "category"
    t.integer  "rank",                  :limit => 2
    t.integer  "num"
    t.integer  "tournament_id"
    t.string   "original_name"
    t.string   "original_fed",          :limit => 3
    t.string   "original_title",        :limit => 3
    t.string   "original_gender",       :limit => 1
    t.integer  "original_icu_id"
    t.integer  "original_fide_id"
    t.integer  "original_icu_rating",   :limit => 2
    t.integer  "original_fide_rating",  :limit => 2
    t.date     "original_dob"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "old_rating",            :limit => 2
    t.integer  "new_rating",            :limit => 2
    t.integer  "trn_rating",            :limit => 2
    t.integer  "old_games",             :limit => 2
    t.integer  "new_games",             :limit => 2
    t.integer  "bonus",                 :limit => 2
    t.integer  "k_factor",              :limit => 1
    t.integer  "last_player_id"
    t.decimal  "actual_score",                       :precision => 3, :scale => 1
    t.decimal  "expected_score",                     :precision => 8, :scale => 6
    t.string   "last_signature"
    t.string   "curr_signature"
    t.boolean  "old_full",                                                         :default => false
    t.boolean  "new_full",                                                         :default => false
    t.boolean  "unrateable",                                                       :default => false
    t.integer  "rating_change",         :limit => 2,                               :default => 0
    t.integer  "pre_bonus_rating",      :limit => 2
    t.integer  "pre_bonus_performance", :limit => 2
  end

  add_index "players", ["fide_id"], :name => "index_players_on_fide_id"
  add_index "players", ["icu_id"], :name => "index_players_on_icu_id"
  add_index "players", ["rating_change"], :name => "index_players_on_rating_change"
  add_index "players", ["tournament_id"], :name => "index_players_on_tournament_id"

  create_table "publications", :force => true do |t|
    t.integer  "rating_list_id"
    t.integer  "last_tournament_id"
    t.text     "report"
    t.datetime "created_at"
    t.integer  "total",              :limit => 3
    t.integer  "creates",            :limit => 3
    t.integer  "remains",            :limit => 3
    t.integer  "updates",            :limit => 3
    t.integer  "deletes",            :limit => 3
    t.text     "notes"
  end

  add_index "publications", ["rating_list_id"], :name => "index_publications_on_rating_list_id"

  create_table "rating_lists", :force => true do |t|
    t.date     "date"
    t.date     "tournament_cut_off"
    t.datetime "created_at"
    t.date     "payment_cut_off"
  end

  add_index "rating_lists", ["date"], :name => "index_rating_lists_on_date"

  create_table "rating_runs", :force => true do |t|
    t.integer  "user_id"
    t.string   "status"
    t.text     "report"
    t.integer  "start_tournament_id"
    t.integer  "last_tournament_id"
    t.integer  "start_tournament_rorder"
    t.integer  "last_tournament_rorder"
    t.string   "start_tournament_name"
    t.string   "last_tournament_name"
    t.datetime "created_at",                                             :null => false
    t.datetime "updated_at",                                             :null => false
    t.string   "reason",                  :limit => 100, :default => "", :null => false
  end

  create_table "results", :force => true do |t|
    t.integer  "round",          :limit => 1
    t.integer  "player_id"
    t.integer  "opponent_id"
    t.string   "result",         :limit => 1
    t.string   "colour",         :limit => 1
    t.boolean  "rateable"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "expected_score",              :precision => 8, :scale => 6
    t.decimal  "rating_change",               :precision => 8, :scale => 6
  end

  add_index "results", ["opponent_id"], :name => "index_results_on_opponent_id"
  add_index "results", ["player_id"], :name => "index_results_on_player_id"
  add_index "results", ["rating_change"], :name => "index_results_on_rating_change"

  create_table "subscriptions", :force => true do |t|
    t.integer  "icu_id"
    t.string   "season",     :limit => 7
    t.string   "category",   :limit => 8
    t.date     "pay_date"
    t.datetime "created_at",              :null => false
    t.datetime "updated_at",              :null => false
  end

  add_index "subscriptions", ["category"], :name => "index_subscriptions_on_category"
  add_index "subscriptions", ["icu_id"], :name => "index_subscriptions_on_icu_id"
  add_index "subscriptions", ["season"], :name => "index_subscriptions_on_season"

  create_table "tournaments", :force => true do |t|
    t.string   "name"
    t.string   "city"
    t.string   "site"
    t.string   "arbiter"
    t.string   "deputy"
    t.string   "tie_breaks"
    t.string   "time_control"
    t.date     "start"
    t.date     "finish"
    t.string   "fed",                    :limit => 3
    t.integer  "rounds",                 :limit => 1
    t.integer  "user_id"
    t.string   "original_name"
    t.string   "original_tie_breaks"
    t.date     "original_start"
    t.date     "original_finish"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status",                               :default => "ok"
    t.string   "stage",                  :limit => 20, :default => "initial"
    t.integer  "rorder"
    t.integer  "reratings",              :limit => 2,  :default => 0
    t.integer  "next_tournament_id"
    t.integer  "last_tournament_id"
    t.integer  "old_last_tournament_id"
    t.datetime "first_rated"
    t.datetime "last_rated"
    t.integer  "last_rated_msec",        :limit => 2
    t.string   "last_signature",         :limit => 32
    t.string   "curr_signature",         :limit => 32
    t.boolean  "locked",                               :default => false
    t.text     "notes"
    t.integer  "fide_id"
    t.integer  "iterations1",            :limit => 2,  :default => 0
    t.integer  "iterations2",            :limit => 2,  :default => 0
    t.boolean  "rerate",                               :default => false
  end

  add_index "tournaments", ["curr_signature"], :name => "index_tournaments_on_curr_signature"
  add_index "tournaments", ["last_rated"], :name => "index_tournaments_on_last_rated"
  add_index "tournaments", ["last_rated_msec"], :name => "index_tournaments_on_last_rated_msec"
  add_index "tournaments", ["last_signature"], :name => "index_tournaments_on_last_signature"
  add_index "tournaments", ["last_tournament_id"], :name => "index_tournaments_on_last_tournament_id"
  add_index "tournaments", ["old_last_tournament_id"], :name => "index_tournaments_on_old_last_tournament_id"
  add_index "tournaments", ["rorder"], :name => "index_tournaments_on_rorder", :unique => true
  add_index "tournaments", ["stage"], :name => "index_tournaments_on_stage"
  add_index "tournaments", ["user_id"], :name => "index_tournaments_on_user_id"

  create_table "uploads", :force => true do |t|
    t.string   "name"
    t.string   "format"
    t.string   "content_type"
    t.string   "file_type"
    t.integer  "size"
    t.integer  "tournament_id"
    t.integer  "user_id"
    t.text     "error"
    t.datetime "created_at"
  end

  add_index "uploads", ["tournament_id"], :name => "index_uploads_on_tournament_id"
  add_index "uploads", ["user_id"], :name => "index_uploads_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "email",           :limit => 50
    t.string   "preferred_email", :limit => 50
    t.string   "password",        :limit => 32
    t.string   "role",            :limit => 20, :default => "member"
    t.integer  "icu_id"
    t.date     "expiry"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "salt",            :limit => 32
    t.string   "status",          :limit => 20, :default => "ok"
    t.datetime "last_pulled_at"
    t.string   "last_pull"
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true

end
