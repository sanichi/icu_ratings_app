require 'spec_helper'

describe "routes" do
  it "pages" do
    get("/").should route_to("pages#home")
    get("/home").should route_to("pages#home")
    get("/contacts").should route_to("pages#contacts")
    get("/my_home").should route_to("pages#my_home")
    get("/my_home/1530").should route_to("pages#my_home", :id => "1530")
  end

  it "404s" do
    get("/foo").should route_to("pages#not_found", url: "foo")
    get("/foo/bar").should route_to("pages#not_found", url: "foo/bar")
  end

  it "non-existant actions" do
    get("/uploads/1/edit").should route_to("pages#not_found", url: "uploads/1/edit")
    post("/fide_player/create").should route_to("pages#not_found", url: "fide_player/create")
    delete("/icu_player/1").should route_to("pages#not_found", url: "icu_player/1")
  end
end
