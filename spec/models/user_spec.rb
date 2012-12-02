require 'spec_helper'

describe User do
  context "validation" do
    it "the factory test user is valid" do
      lambda { FactoryGirl.create(:user) }.should_not raise_error
    end

    it "should not allow duplicate emails (case insensitively)" do
      user = FactoryGirl.create(:user)
      lambda { FactoryGirl.create(:user, email: user.email) }.should raise_error(/email.*already.*taken/i)
      lambda { FactoryGirl.create(:user, email: user.email.upcase) }.should raise_error(/email.*already.*taken/i)
    end

    it "should reject invalid roles" do
      lambda { FactoryGirl.create(:user, role: "superuser") }.should raise_error(/role.*invalid/i)
    end

    it "should have a minimum expiry date" do
      lambda { FactoryGirl.create(:user, expiry: "2003-12-31") }.should raise_error(/expiry must be/i)
      lambda { FactoryGirl.create(:user, expiry: "2005-12-31") }.should_not raise_error
    end
  end

  context "roles" do
    it "members" do
      user = FactoryGirl.create(:user)
      user.role?(:member).should be_true
      user.role?(:reporter).should be_false
      user.role?(:officer).should be_false
      user.role?(:admin).should be_false
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "tournament reporters" do
      user = FactoryGirl.create(:user, role: "reporter")
      user.role?(:member).should be_true
      user.role?(:reporter).should be_true
      user.role?(:officer).should be_false
      user.role?(:admin).should be_false
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "rating officers" do
      user = FactoryGirl.create(:user, role: "officer")
      user.role?(:member).should be_true
      user.role?(:reporter).should be_true
      user.role?(:officer).should be_true
      user.role?(:admin).should be_false
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "administrators" do
      user = FactoryGirl.create(:user, role: "admin")
      user.role?(:member).should be_true
      user.role?(:reporter).should be_true
      user.role?(:officer).should be_true
      user.role?(:admin).should be_true
      user.role?("anything else").should be_false
      user.role?(nil).should be_false
    end

    it "invalid roles" do
      ["invalid", "", nil].each do |role|
        user = FactoryGirl.build(:user, role: role)
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
      @user = FactoryGirl.create(:user)
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

  context "password_ok?" do
    before(:each) do
      @p = 'icuicj'
      @u1 = FactoryGirl.create(:user, password: "be3ab3d3be49b8304b8604a3268dfcf2", salt: "b3f0f553a916b0e8ab6b2469cabd200f")
      @u2 = FactoryGirl.create(:user, password: @p)
    end

    it "with salt" do
      @u1.password_ok?(@p).should be_true
    end

    it "without salt" do
      @u2.password_ok?(@p).should be_true
    end

    it "with salt special case for admin" do
      @u1.password_ok?(@u1.password, false).should be_false
      @u1.password_ok?(@u1.password,  true).should be_true
    end
  end

  context "change_password" do
    before(:each) do
      pass = "icuicj"
      salt = "b3f0f553a916b0e8ab6b2469cabd200f"
      password = eval(APP_CONFIG["hasher"])
      @p = pass
      @u1 = FactoryGirl.create(:user, password: password, salt: salt)
      @u2 = FactoryGirl.create(:user, password: @p)
      ICU::Database::Push.stub_chain(:new, :update_password).and_return(nil)
    end

    it "new password, old salt" do
      @q = "password1"
      params = { new_password: @q }
      @u1.change_password(params).should be_true
      params[:new_password].should_not be_present
      params[:salt].should_not be_present
      params[:password].should be_present
      params[:password].length.should == 32
      @u1.password_ok?(@p).should be_true
      @u1.password = params[:password]
      @u1.password_ok?(@p).should be_false
      @u1.password_ok?(@q).should be_true
      @u1.errors.should be_empty
    end

    it "new password, new salt" do
      @q = "password2"
      params = { new_password: @q }
      @u2.change_password(params).should be_true
      params[:new_password].should_not be_present
      params[:salt].should be_present
      params[:salt].length.should == 32
      params[:password].should be_present
      params[:password].length.should == 32
      @u2.password_ok?(@p).should be_true
      @u2.password = params[:password]
      @u2.salt = params[:salt]
      @u2.password_ok?(@p).should be_false
      @u2.password_ok?(@q).should be_true
    end

    it "no (or blank) password" do
      params = { }
      @u1.change_password(params).should be_true
      @u1.errors.should be_empty
      params[:new_password].should_not be_present
      params[:password].should_not be_present
      params[:salt].should_not be_present
      params = { new_password: "    " }
      @u1.change_password(params).should be_true
      @u1.errors.should be_empty
      params[:new_password].should_not be_present
      params[:password].should_not be_present
      params[:salt].should_not be_present
    end

    it "password too short or too long" do
      params = { new_password: "123" }
      @u1.change_password(params).should be_false
      @u1.errors.should_not be_empty
      params[:password].should_not be_present
      params[:salt].should_not be_present
      params = { new_password: "1234567890123456789012345678901234567890" }
      @u1.change_password(params).should be_false
      @u1.errors.should_not be_empty
      params[:password].should_not be_present
      params[:salt].should_not be_present
    end

    it "ICU database push fails" do
      ICU::Database::Push.stub_chain(:new, :update_password).and_return("woops")
      params = { new_password: "password3" }
      @u1.change_password(params).should be_false
      params[:new_password].should_not be_present
      params[:salt].should_not be_present
      params[:password].should_not be_present
      @u1.errors.should_not be_empty
    end
  end
end
