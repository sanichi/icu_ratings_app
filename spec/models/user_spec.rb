require 'spec_helper'

describe User do
  context "validation" do
    it "the factory test user is valid" do
      lambda { Factory(:user) }.should_not raise_error
    end

    it "should not allow duplicate emails (case insensitively)" do
      user = Factory(:user)
      lambda { Factory(:user, :email => user.email) }.should raise_error(/email.*already.*taken/i)
      lambda { Factory(:user, :email => user.email.upcase) }.should raise_error(/email.*already.*taken/i)
    end

    it "should reject invalid roles" do
      lambda { Factory(:user, :role => "superuser") }.should raise_error(/role.*invalid/i)
    end

    it "should have a minimum expiry date" do
      lambda { Factory(:user, :expiry => "2003-12-31") }.should raise_error(/expiry must be/i)
      lambda { Factory(:user, :expiry => "2005-12-31") }.should_not raise_error
    end
  end

  context "roles" do
    it "members" do
      user = Factory(:user)
      user.role?(:member).should be_true
      user.role?(:reporter).should be_false
      user.role?(:officer).should be_false
      user.role?(:admin).should be_false
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "tournament reporters" do
      user = Factory(:user, :role => "reporter")
      user.role?(:member).should be_true
      user.role?(:reporter).should be_true
      user.role?(:officer).should be_false
      user.role?(:admin).should be_false
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "rating officers" do
      user = Factory(:user, :role => "officer")
      user.role?(:member).should be_true
      user.role?(:reporter).should be_true
      user.role?(:officer).should be_true
      user.role?(:admin).should be_false
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "administrators" do
      user = Factory(:user, :role => "admin")
      user.role?(:member).should be_true
      user.role?(:reporter).should be_true
      user.role?(:officer).should be_true
      user.role?(:admin).should be_true
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "invalid roles" do
      ["invalid", "", nil].each do |role|
        user = Factory.build(:user, :role => role)
        user.role?(:member).should be_false
        user.role?(:reporter).should be_false
        user.role?(:officer).should be_false
        user.role?(:admin).should be_false
        user.role?("anything else").should be_false
        user.role?(nil).should be_false
      end
    end
  end

  context "best email" do
    before(:each) do
      @user = Factory(:user)
    end

    it "should be the IcuPlayer's email" do
      @user.best_email.should == @user.icu_player.email
    end

    it "unless that is missing, in which case it is the login email" do
      @user.icu_player.email = nil
      @user.best_email.should == @user.email
    end
    
    it "unless there is a preferred email, in which case that takes precedence" do
      @user.preferred_email = Faker::Internet.email
      @user.best_email.should == @user.preferred_email
    end
  end
end
