require 'spec_helper'

describe User do
  context "validation" do
    it "the factory test user is valid" do
      expect { FactoryGirl.create(:user) }.to_not raise_error
    end

    it "should not allow duplicate emails (case insensitively)" do
      user = FactoryGirl.create(:user)
      expect { FactoryGirl.create(:user, email: user.email) }.to raise_error(/email.*already.*taken/i)
      expect { FactoryGirl.create(:user, email: user.email.upcase) }.to raise_error(/email.*already.*taken/i)
    end

    it "should reject invalid roles" do
      expect { FactoryGirl.create(:user, role: "superuser") }.to raise_error(/role.*invalid/i)
    end

    it "should have a minimum expiry date" do
      expect { FactoryGirl.create(:user, expiry: "2003-12-31") }.to raise_error(/expiry must be/i)
      expect { FactoryGirl.create(:user, expiry: "2005-12-31") }.to_not raise_error
    end
  end

  context "roles" do
    it "members" do
      user = FactoryGirl.create(:user)
      expect(user.role?(:member)).to be true
      expect(user.role?(:reporter)).to be false
      expect(user.role?(:officer)).to be false
      expect(user.role?(:admin)).to be false
      expect(user.role?("anything else")).to be false
      expect(user.role?(nil)).to be false
    end

    it "tournament reporters" do
      user = FactoryGirl.create(:user, role: "reporter")
      expect(user.role?(:member)).to be true
      expect(user.role?(:reporter)).to be true
      expect(user.role?(:officer)).to be false
      expect(user.role?(:admin)).to be false
      expect(user.role?("anything else")).to be false
      expect(user.role?(nil)).to be false
    end

    it "rating officers" do
      user = FactoryGirl.create(:user, role: "officer")
      expect(user.role?(:member)).to be true
      expect(user.role?(:reporter)).to be true
      expect(user.role?(:officer)).to be true
      expect(user.role?(:admin)).to be false
      expect(user.role?("anything else")).to be false
      expect(user.role?(nil)).to be false
    end

    it "administrators" do
      user = FactoryGirl.create(:user, role: "admin")
      expect(user.role?(:member)).to be true
      expect(user.role?(:reporter)).to be true
      expect(user.role?(:officer)).to be true
      expect(user.role?(:admin)).to be true
      expect(user.role?("anything else")).to be false
      expect(user.role?(nil)).to be false
    end

    it "invalid roles" do
      ["invalid", "", nil].each do |role|
        user = FactoryGirl.build(:user, role: role)
        expect(user.role?(:member)).to be false
        expect(user.role?(:reporter)).to be false
        expect(user.role?(:officer)).to be false
        expect(user.role?(:admin)).to be false
        expect(user.role?("anything else")).to be false
        expect(user.role?(nil)).to be false
      end
    end
  end

  context "best email" do
    before(:each) do
      @user = FactoryGirl.create(:user)
    end

    it "should be the IcuPlayer's email" do
      expect(@user.best_email).to eq(@user.icu_player.email)
    end

    it "unless that is missing, in which case it is the login email" do
      @user.icu_player.email = nil
      expect(@user.best_email).to eq(@user.email)
    end

    it "unless there is a preferred email, in which case that takes precedence" do
      @user.preferred_email = Faker::Internet.email
      expect(@user.best_email).to eq(@user.preferred_email)
    end
  end

  context "#password_ok?" do
    before(:each) do
      @p = "icuicj"
      @u1 = FactoryGirl.create(:user, password: "be3ab3d3be49b8304b8604a3268dfcf2", salt: "b3f0f553a916b0e8ab6b2469cabd200f")
      @u2 = FactoryGirl.create(:user, password: @p)
    end

    it "with salt" do
      expect(@u1.password_ok?(@p)).to be true
    end

    it "without salt" do
      expect(@u2.password_ok?(@p)).to be true
    end

    it "with salt special case for admin" do
      expect(@u1.password_ok?(@u1.password, false)).to be false
      expect(@u1.password_ok?(@u1.password,  true)).to be true
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
      expect(User.authenticate!({ email: @e, password: @p }, @i, false)).to eq(@u)
    end

    it "use of hashed password requires admin" do
      expect { User.authenticate!({ email: @e, password: @h }, @i, true) }.to_not raise_error
      expect { User.authenticate!({ email: @e, password: @h }, @i, false) }.to raise_error(/invalid/i)
    end

    it "expiry date" do
      @u.expiry = Date.yesterday
      @u.save
      expect { User.authenticate!({ email: @e, password: @p }, @i, false) }.to raise_error(/(expired|lapsed|suspended)/i)
    end

    it "status" do
      @u.status = "pending"
      @u.save
      expect { User.authenticate!({ email: @e, password: @p }, @i, false) }.to raise_error(/activat/i)
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
      expect(@u1.update_www_member(@params)).to be true
      expect(@params[:new_password]).to_not be_present
      expect(@params[:salt]).to_not be_present
      expect(@params[:password]).to be_present
      expect(@params[:password].length).to eq(32)
      expect(@params[:status]).to_not be_present
      expect(@u1.password_ok?(@p)).to be true
      @u1.password = @params[:password]
      expect(@u1.password_ok?(@p)).to be false
      expect(@u1.password_ok?(@q)).to be true
      expect(@u1.errors).to be_empty
    end

    it "new password, new salt" do
      @q = "password2"
      @params[:new_password] = @q
      expect(@u2.update_www_member(@params)).to be true
      expect(@params[:new_password]).to_not be_present
      expect(@params[:salt]).to be_present
      expect(@params[:salt].length).to eq(32)
      expect(@params[:password]).to be_present
      expect(@params[:password].length).to eq(32)
      expect(@params[:status]).to_not be_present
      expect(@u2.password_ok?(@p)).to be true
      @u2.password = @params[:password]
      @u2.salt = @params[:salt]
      expect(@u2.password_ok?(@p)).to be false
      expect(@u2.password_ok?(@q)).to be true
    end

    it "new status" do
      @u1.status = "pending"
      expect(@u1.update_www_member(@params)).to be true
      expect(@params[:status]).to eq("ok")
      @params = { status: "pending" }
      @u1.status = "ok"
      expect(@u1.update_www_member(@params)).to be true
      expect(@params[:status]).to eq("pending")
    end

    it "no (or blank) password" do
      expect(@u1.update_www_member(@params)).to be true
      expect(@u1.errors).to be_empty
      expect(@params[:new_password]).to_not be_present
      expect(@params[:password]).to_not be_present
      expect(@params[:salt]).to_not be_present
      expect(@params[:status]).to_not be_present
      @params = { new_password: "    ", status: "ok" }
      expect(@u1.update_www_member(@params)).to be true
      expect(@u1.errors).to be_empty
      expect(@params[:new_password]).to_not be_present
      expect(@params[:password]).to_not be_present
      expect(@params[:salt]).to_not be_present
    end

    it "password too short or too long" do
      @params[:new_password] = "123"
      expect(@u1.update_www_member(@params)).to be_nil
      expect(@u1.errors).to_not be_empty
      expect(@params[:password]).to_not be_present
      expect(@params[:salt]).to_not be_present
      expect(@params[:status]).to_not be_present
      @params = { new_password: "1234567890123456789012345678901234567890" }
      expect(@u1.update_www_member(@params)).to be_nil
      expect(@u1.errors).to_not be_empty
      expect(@params[:password]).to_not be_present
      expect(@params[:salt]).to_not be_present
    end

    it "ICU database push fails" do
      ICU::Database::Push.stub_chain(:new, :update_member).and_return("woops")
      @params[:new_password] = "password3"
      expect(@u1.update_www_member(@params)).to be_nil
      expect(@params[:new_password]).to_not be_present
      expect(@params[:salt]).to_not be_present
      expect(@params[:password]).to_not be_present
      expect(@params[:status]).to_not be_present
      expect(@u1.errors[:base].first).to_not be_empty
      expect(@u1.errors[:base].first).to match(/woops/)
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
      expect(@user.password).to  eq(@h[:password])
      expect(@user.salt).to      eq(@h[:salt])
      expect(@user.status).to    eq(@h[:status])
      expect(@user.expiry).to    eq(@h[:expiry])
      expect(Failure.count).to   eq(0)
      expect(@user.last_pull).to eq("none")
      expect(@user.last_pulled_at).to be_within(1).of(Time.now)
    end

    it "changed password" do
      password = "abcdefabcdefabcdefabcdefabcdef11"
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return(@h.merge(password: password))
      @user.pull_www_member
      expect(@user.password).to  eq(password)
      expect(@user.salt).to      eq(@h[:salt])
      expect(@user.status).to    eq(@h[:status])
      expect(@user.expiry).to    eq(@h[:expiry])
      expect(Failure.count).to   eq(0)
      expect(@user.last_pull).to eq("password")
      expect(@user.last_pulled_at).to be_within(1).of(Time.now)
    end

    it "changed salt and password" do
      password = "abcdefabcdefabcdefabcdefabcdef12"
      salt     = "abcdefabcdefabcdefabcdefabcdef22"
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return(@h.merge(password: password, salt: salt))
      @user.pull_www_member
      expect(@user.password).to  eq(password)
      expect(@user.salt).to      eq(salt)
      expect(@user.status).to    eq(@h[:status])
      expect(@user.expiry).to    eq(@h[:expiry])
      expect(Failure.count).to   eq(0)
      expect(@user.last_pull).to eq("password, salt")
      expect(@user.last_pulled_at).to be_within(1).of(Time.now)
    end

    it "changed status and expiry" do
      status = "pending"
      expiry = Date.new(2013, 12, 31)
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return(@h.merge(status: status, expiry: expiry))
      @user.pull_www_member
      expect(@user.password).to  eq(@h[:password])
      expect(@user.salt).to      eq(@h[:salt])
      expect(@user.status).to    eq(status)
      expect(@user.expiry).to    eq(expiry)
      expect(Failure.count).to   eq(0)
      expect(@user.last_pull).to eq("status, expiry")
      expect(@user.last_pulled_at).to be_within(1).of(Time.now)
    end

    it "an error" do
      ICU::Database::Pull.stub_chain(:new, :get_member).with(@user.id, @user.email).and_return("error xxx")
      @user.pull_www_member
      expect(@user.password).to  eq(@h[:password])
      expect(@user.salt).to      eq(@h[:salt])
      expect(@user.status).to    eq(@h[:status])
      expect(@user.expiry).to    eq(@h[:expiry])
      expect(@user.last_pull).to be_nil
      expect(@user.last_pulled_at).to be_nil
      expect(Failure.count).to   eq(1)
      expect(Failure.first.details).to match(/error xxx/)
    end
  end
end
