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

  context "#password_ok?" do
    before(:each) do
      @p = "icuicj"
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

  context "#authenticate!" do
    before(:each) do
      @i = "192.168.2.165"
      @p = "icuicj"
      @e = "joe@example.com"
      @h = "be3ab3d3be49b8304b8604a3268dfcf2"
      @s = "b3f0f553a916b0e8ab6b2469cabd200f"
      @u = FactoryGirl.create(:user, email: @e, password: @h, salt: @s)
    end

    it "valid login" do
      User.authenticate!({ email: @e, password: @p }, @i, false).should == @u
    end

    it "use of hashed password requires admin" do
      lambda { User.authenticate!({ email: @e, password: @h }, @i, true) }.should_not raise_error
      lambda { User.authenticate!({ email: @e, password: @h }, @i, false) }.should raise_error(/invalid/i)
    end

    it "expiry date" do
      @u.expiry = Date.yesterday
      @u.save
      lambda { User.authenticate!({ email: @e, password: @p }, @i, false) }.should raise_error(/expir/i)
    end

    it "status" do
      @u.status = "pending"
      @u.save
      lambda { User.authenticate!({ email: @e, password: @p }, @i, false) }.should raise_error(/activat/i)
    end
  end

  context "#update_www_member" do
    before(:each) do
      pass = "icuicj"
      salt = "b3f0f553a916b0e8ab6b2469cabd200f"
      password = eval(APP_CONFIG["hasher"])
      @p = pass
      @u1 = FactoryGirl.create(:user, password: password, salt: salt)
      @u2 = FactoryGirl.create(:user, password: @p)
      @params = { status: "ok" }
      ICU::Database::Push.stub_chain(:new, :update_member).and_return(nil)
    end

    it "new password, old salt" do
      @q = "password1"
      @params[:new_password] = @q
      @u1.update_www_member(@params).should be_true
      @params[:new_password].should_not be_present
      @params[:salt].should_not be_present
      @params[:password].should be_present
      @params[:password].length.should == 32
      @params[:status].should_not be_present
      @u1.password_ok?(@p).should be_true
      @u1.password = @params[:password]
      @u1.password_ok?(@p).should be_false
      @u1.password_ok?(@q).should be_true
      @u1.errors.should be_empty
    end

    it "new password, new salt" do
      @q = "password2"
      @params[:new_password] = @q
      @u2.update_www_member(@params).should be_true
      @params[:new_password].should_not be_present
      @params[:salt].should be_present
      @params[:salt].length.should == 32
      @params[:password].should be_present
      @params[:password].length.should == 32
      @params[:status].should_not be_present
      @u2.password_ok?(@p).should be_true
      @u2.password = @params[:password]
      @u2.salt = @params[:salt]
      @u2.password_ok?(@p).should be_false
      @u2.password_ok?(@q).should be_true
    end

    it "new status" do
      @u1.status = "pending"
      @u1.update_www_member(@params).should be_true
      @params[:status].should == "ok"
      @params = { status: "pending" }
      @u1.status = "ok"
      @u1.update_www_member(@params).should be_true
      @params[:status].should == "pending"
    end

    it "no (or blank) password" do
      @u1.update_www_member(@params).should be_true
      @u1.errors.should be_empty
      @params[:new_password].should_not be_present
      @params[:password].should_not be_present
      @params[:salt].should_not be_present
      @params[:status].should_not be_present
      @params = { new_password: "    ", status: "ok" }
      @u1.update_www_member(@params).should be_true
      @u1.errors.should be_empty
      @params[:new_password].should_not be_present
      @params[:password].should_not be_present
      @params[:salt].should_not be_present
    end

    it "password too short or too long" do
      @params[:new_password] = "123"
      @u1.update_www_member(@params).should be_false
      @u1.errors.should_not be_empty
      @params[:password].should_not be_present
      @params[:salt].should_not be_present
      @params[:status].should_not be_present
      @params = { new_password: "1234567890123456789012345678901234567890" }
      @u1.update_www_member(@params).should be_false
      @u1.errors.should_not be_empty
      @params[:password].should_not be_present
      @params[:salt].should_not be_present
    end

    it "ICU database push fails" do
      ICU::Database::Push.stub_chain(:new, :update_member).and_return("woops")
      @params[:new_password] = "password3"
      @u1.update_www_member(@params).should be_false
      @params[:new_password].should_not be_present
      @params[:salt].should_not be_present
      @params[:password].should_not be_present
      @params[:status].should_not be_present
      @u1.errors[:base].first.should_not be_empty
      @u1.errors[:base].first.should match(/woops/)
    end
  end

  context "#pull_www_member" do
    before(:each) do
      @h =
      {
        salt:     "abcdefabcdefabcdefabcdefabcdef10",
        password: "abcdefabcdefabcdefabcdefabcdef20",
        status:   "ok",
        expiry:   Date.new(2012, 12, 31),
      }
      @user = FactoryGirl.create(:user, @h)
    end

    before(:all) do
      User.pulls_disabled = false
    end

    after(:all) do
      User.pulls_disabled = true
    end

    it "no change" do
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return(@h)
      @user.pull_www_member
      @user.password.should  == @h[:password]
      @user.salt.should      == @h[:salt]
      @user.status.should    == @h[:status]
      @user.expiry.should    == @h[:expiry]
      Failure.count.should   == 0
      @user.last_pull.should == "none"
      @user.last_pulled_at.should be_within(1).of(Time.now)
    end

    it "changed password" do
      password = "abcdefabcdefabcdefabcdefabcdef11"
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return(@h.merge(password: password))
      @user.pull_www_member
      @user.password.should  == password
      @user.salt.should      == @h[:salt]
      @user.status.should    == @h[:status]
      @user.expiry.should    == @h[:expiry]
      Failure.count.should   == 0
      @user.last_pull.should == "password"
      @user.last_pulled_at.should be_within(1).of(Time.now)
    end

    it "changed salt and password" do
      password = "abcdefabcdefabcdefabcdefabcdef12"
      salt     = "abcdefabcdefabcdefabcdefabcdef22"
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return(@h.merge(password: password, salt: salt))
      @user.pull_www_member
      @user.password.should  == password
      @user.salt.should      == salt
      @user.status.should    == @h[:status]
      @user.expiry.should    == @h[:expiry]
      Failure.count.should   == 0
      @user.last_pull.should == "password, salt"
      @user.last_pulled_at.should be_within(1).of(Time.now)
    end

    it "changed status and expiry" do
      status = "pending"
      expiry = Date.new(2013, 12, 31)
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return(@h.merge(status: status, expiry: expiry))
      @user.pull_www_member
      @user.password.should  == @h[:password]
      @user.salt.should      == @h[:salt]
      @user.status.should    == status
      @user.expiry.should    == expiry
      Failure.count.should   == 0
      @user.last_pull.should == "status, expiry"
      @user.last_pulled_at.should be_within(1).of(Time.now)
    end

    it "an error" do
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return("error xxx")
      @user.pull_www_member
      @user.password.should  == @h[:password]
      @user.salt.should      == @h[:salt]
      @user.status.should    == @h[:status]
      @user.expiry.should    == @h[:expiry]
      @user.last_pull.should be_nil
      @user.last_pulled_at.should be_nil
      Failure.count.should   == 1
      Failure.first.details.should match(/error xxx/)
    end
  end
end
