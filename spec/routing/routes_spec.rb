require 'spec_helper'

describe "routes" do
  it "pages" do
    expect(get("/")).to route_to("pages#home")
    expect(get("/home")).to route_to("pages#home")
    expect(get("/contacts")).to route_to("pages#contacts")
    expect(get("/my_home")).to route_to("pages#my_home")
    expect(get("/their_home/1530")).to route_to("pages#their_home", :id => "1530")
  end

  it "404s" do
    expect(get("/foo")).to route_to("pages#not_found", url: "foo")
    expect(get("/foo/bar")).to route_to("pages#not_found", url: "foo/bar")
    expect(get("/apple-touch-icon.png")).to route_to("pages#not_found", url: "apple-touch-icon", format: "png")
    expect(get("/crossdomain.xml")).to route_to("pages#not_found", url: "crossdomain", format: "xml")
  end

  it "non-existant actions" do
    expect(get("/uploads/1/edit")).to route_to("pages#not_found", url: "uploads/1/edit")
    expect(post("/fide_player/create")).to route_to("pages#not_found", url: "fide_player/create")
    expect(delete("/icu_player/1")).to route_to("pages#not_found", url: "icu_player/1")
  end
end
