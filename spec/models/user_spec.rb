#
#
# == License:
# Fairnopoly - Fairnopoly is an open-source online marketplace.
# Copyright (C) 2013 Fairnopoly eG
#
# This file is part of Fairnopoly.
#
# Fairnopoly is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Fairnopoly is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Fairnopoly.  If not, see <http://www.gnu.org/licenses/>.
#
require 'spec_helper'

describe User do

  let(:user) { FactoryGirl.create(:user) }
  subject { user }

  it "has a valid Factory" do
    should be_valid
  end

  describe "associations" do
    it { should have_many(:articles).dependent(:destroy) }
    #it { should have_many(:bids).dependent(:destroy) }
    #it { should have_many(:invitations).dependent(:destroy) }
    it { should have_many(:article_templates).dependent(:destroy) }
    it { should have_many(:libraries).dependent(:destroy) }
    #it { should belong_to :invitor}
    it { should have_one(:image) }
  end

  describe "validations" do

    context "always" do
      it {should validate_presence_of :email}
      it {should validate_presence_of :nickname}
      it {should validate_uniqueness_of :nickname}
    end

    context "on create" do
      subject { User.new }
      it { should validate_acceptance_of :privacy }
      it { should validate_acceptance_of :legal }
      it { should validate_acceptance_of :agecheck }
      it { should validate_presence_of :recaptcha }
    end

    context "on update" do
      it { should validate_presence_of :forename }
      it { should validate_presence_of :surname }

      describe "zip code validation" do
        before :each do
          user.country = "Deutschland"
        end
        it {should allow_value('12345').for :zip}
        it {should_not allow_value('a1b2c').for :zip}
        it {should_not allow_value('123456').for :zip}
        it {should_not allow_value('1234').for :zip}
      end

      describe "address validation" do
        it {should allow_value('Test Str. 1a').for :street}
        it {should_not allow_value('Test Str.').for :street}
      end
    end

    context "if user wants to sell" do
      before :each do
        user.wants_to_sell = true
      end

      it {should validate_presence_of :zip}
      it { should validate_presence_of :country }
      it { should validate_presence_of :street }
      it { should validate_presence_of :city }
    end
  end

  describe "methods" do
    describe "#fullname" do
      it "returns correct fullname" do
        user.fullname.should eq "#{user.forename} #{user.surname}"
      end
    end

    describe "#name" do
      it "returns correct name" do
        user.name.should eq user.nickname
      end
    end

    describe "#is?" do
      it "should return true when users have the same ID" do
        user.is?(user).should be_true
      end

      it "should return false when users don't have the same ID" do
        user.is?(FactoryGirl.create(:user)).should be_false
      end
    end

    describe "#customer_nr" do
      it "should have 8 digits" do
        user.customer_nr.length.should eq 8
      end

      it "should use the user_id" do
        user.customer_nr.should eq "0000000#{user.id}"
      end
    end

    describe "paypal_account_exists?" do
      it "should be true if user has paypal account" do
        FactoryGirl.create(:user, :paypal_data).paypal_account_exists?.should be_true
      end
      it "should be false if user does not have paypal account" do
        user.paypal_account_exists?.should be_false
      end
    end

    describe "bank_account_exists?" do
      it "should be true if user has bank account" do
        user.bank_account_exists?.should be_true
      end
      it "should be false if user does not have bank account" do
        FactoryGirl.create(:user, :no_bank_data).bank_account_exists?.should be_false
      end
    end

  end


  describe "subclasses" do
    describe PrivateUser do
      let(:user) { FactoryGirl::create(:private_user) }
      subject { user }

      it "should have a valid factory" do
        should be_valid
      end

      it "should return the same model_name as User" do
        PrivateUser.model_name.should eq User.model_name
      end
    end

    describe LegalEntity do
      let(:user) { FactoryGirl::create(:legal_entity) }
      subject { user }

      it "should have a valid factory" do
        should be_valid
      end

      it "should return the same model_name as User" do
        LegalEntity.model_name.should eq User.model_name
      end
    end
  end

  describe "states" do
    describe "seller_states" do
      describe PrivateUser do
        let(:private_seller) { FactoryGirl::create(:private_user) }
        subject { private_seller }
        context "being a bad seller" do
          before :each do
            private_seller.seller_state = "bad_seller"
          end

          it "should be able to rate to standard seller" do
            private_seller.rate_up_to_standard_seller
            private_seller.should be_standard_seller
          end
          it "should not be able to rate to good seller" do
            private_seller.rate_up_to_good_seller
            private_seller.should be_bad_seller
          end

          context "if not trusted and not verified" do
            it "should have a salesvolume of 17" do
              private_seller.verified = false
              private_seller.trustcommunity = false
              private_seller.sales_volume. should eq 17
            end
          end
          context "if trusted" do
            it "should have a salesvolume of 17" do
              private_seller.verified = false
              private_seller.trustcommunity = true
              private_seller.sales_volume. should eq 17
            end
          end
          context "if verified" do
            it "should have a salesvolume of 17" do
              private_seller.verified = true
              private_seller.trustcommunity = false
              private_seller.sales_volume. should eq 17
            end
          end
          context "if trusted and verified" do
            it "should have a salesvolume of 17" do
              private_seller.verified = true
              private_seller.trustcommunity = true
              private_seller.sales_volume. should eq 17
            end
          end
        end

        context "being a standard seller" do
          before :each do
            private_seller.seller_state = "standard_seller"
          end

          it "should be able to rate to bad seller" do
            private_seller.rate_down_to_bad_seller
            private_seller.should be_bad_seller
          end
          it "should be able to rate to good seller" do
            private_seller.rate_up_to_good_seller
            private_seller.should be_good_seller
          end

          context "if not trusted and not verified" do
            it "should have a salesvolume of 35" do
              private_seller.verified = false
              private_seller.trustcommunity = false
              private_seller.sales_volume. should eq 35
            end
          end
          context "if trusted" do
            it "should have a salesvolume of 55" do
              private_seller.verified = false
              private_seller.trustcommunity = true
              private_seller.sales_volume. should eq 55
            end
          end
          context "if verified" do
            it "should have a salesvolume of 45" do
              private_seller.verified = true
              private_seller.trustcommunity = false
              private_seller.sales_volume. should eq 45
            end
          end
          context "if trusted and verified" do
            it "should have a salesvolume of 65" do
              private_seller.verified = true
              private_seller.trustcommunity = true
              private_seller.sales_volume. should eq 65
            end
          end
        end

        context "being a good seller" do
          before :each do
            private_seller.seller_state = "good_seller"
          end

          it "should be able to rate to bad seller" do
            private_seller.rate_down_to_bad_seller
            private_seller.should be_bad_seller
          end
          it "should not be able to rate to standard seller" do
            private_seller.rate_up_to_standard_seller
            private_seller.should be_good_seller
          end

          context "if not trusted and not verified" do
            it "should have a salesvolume of 70" do
              private_seller.verified = false
              private_seller.trustcommunity = false
              private_seller.sales_volume. should eq 70
            end
          end
          context "if trusted" do
            it "should have a salesvolume of 110" do
              private_seller.verified = false
              private_seller.trustcommunity = true
              private_seller.sales_volume. should eq 110
            end
          end
          context "if verified" do
            it "should have a salesvolume of 90" do
              private_seller.verified = true
              private_seller.trustcommunity = false
              private_seller.sales_volume. should eq 90
            end
          end
          context "if trusted and verified" do
            it "should have a salesvolume of 130" do
              private_seller.verified = true
              private_seller.trustcommunity = true
              private_seller.sales_volume. should eq 130
            end
          end
        end

        it "should have valid private_seller_constants" do
          private_seller.private_seller_constants[:standard_salesvolume].should eq 35
          private_seller.private_seller_constants[:verified_bonus].should eq 10
          private_seller.private_seller_constants[:trusted_bonus].should eq 20
          private_seller.private_seller_constants[:good_factor].should eq 2
          private_seller.private_seller_constants[:bad_factor].should eq 2
        end
      end

      describe LegalEntity do
        let(:commercial_seller) { FactoryGirl::create(:legal_entity) }
        subject { commercial_seller }
        context "being a bad seller" do
          before :each do
            commercial_seller.seller_state = "bad_seller"
          end

          it "should be able to rate to standard seller" do
            commercial_seller.rate_up_to_standard_seller
            commercial_seller.should be_standard_seller
          end
          it "should not be able to rate to good1 seller" do
            commercial_seller.rate_up_to_good1_seller
            commercial_seller.should be_bad_seller
          end
          it "should not be able to rate to good2 seller" do
            commercial_seller.rate_up_to_good2_seller
            commercial_seller.should be_bad_seller
          end
          it "should not be able to rate to good3 seller" do
            commercial_seller.rate_up_to_good3_seller
            commercial_seller.should be_bad_seller
          end
          it "should not be able to rate to good4 seller" do
            commercial_seller.rate_up_to_good4_seller
            commercial_seller.should be_bad_seller
          end

          context "if not verified" do
            it "should have a salesvolume of 17" do
              commercial_seller.verified = false
              commercial_seller.sales_volume. should eq 17
            end
          end
          context "if verified" do
            it "should have a salesvolume of 17" do
              commercial_seller.verified = true
              commercial_seller.sales_volume. should eq 17
            end
          end
        end

         context "being a standard seller" do
          before :each do
            commercial_seller.seller_state = "standard_seller"
          end

          it "should be able to rate to bad seller" do
            commercial_seller.rate_down_to_bad_seller
            commercial_seller.should be_bad_seller
          end
          it "should be able to rate to good1 seller" do
            commercial_seller.rate_up_to_good1_seller
            commercial_seller.should be_good1_seller
          end
          it "should not be able to rate to good2 seller" do
            commercial_seller.rate_up_to_good2_seller
            commercial_seller.should be_standard_seller
          end
          it "should not be able to rate to good3 seller" do
            commercial_seller.rate_up_to_good3_seller
            commercial_seller.should be_standard_seller
          end
          it "should not be able to rate to good4 seller" do
            commercial_seller.rate_up_to_good4_seller
            commercial_seller.should be_standard_seller
          end

          context "if not verified" do
            it "should have a salesvolume of 35" do
              commercial_seller.verified = false
              commercial_seller.sales_volume. should eq 35
            end
          end
          context "if verified" do
            it "should have a salesvolume of 85" do
              commercial_seller.verified = true
              commercial_seller.sales_volume. should eq 85
            end
          end
        end

        context "being a good1 seller" do
          before :each do
            commercial_seller.seller_state = "good1_seller"
          end

          it "should be able to rate to bad seller" do
            commercial_seller.rate_down_to_bad_seller
            commercial_seller.should be_bad_seller
          end
          it "should not be able to rate to standard seller" do
            commercial_seller.rate_up_to_standard_seller
            commercial_seller.should be_good1_seller
          end
          it "should be able to rate to good2 seller" do
            commercial_seller.rate_up_to_good2_seller
            commercial_seller.should be_good2_seller
          end
          it "should not be able to rate to good3 seller" do
            commercial_seller.rate_up_to_good3_seller
            commercial_seller.should be_good1_seller
          end
          it "should not be able to rate to good4 seller" do
            commercial_seller.rate_up_to_good4_seller
            commercial_seller.should be_good1_seller
          end

          context "if not verified" do
            it "should have a salesvolume of 70" do
              commercial_seller.verified = false
              commercial_seller.sales_volume. should eq 70
            end
          end
          context "if verified" do
            it "should have a salesvolume of 170" do
              commercial_seller.verified = true
              commercial_seller.sales_volume. should eq 170
            end
          end
        end

        context "being a good2 seller" do
          before :each do
            commercial_seller.seller_state = "good2_seller"
          end

          it "should be able to rate to bad seller" do
            commercial_seller.rate_down_to_bad_seller
            commercial_seller.should be_bad_seller
          end
          it "should not be able to rate to standard seller" do
            commercial_seller.rate_up_to_standard_seller
            commercial_seller.should be_good2_seller
          end
          it "should not be able to rate to good1 seller" do
            commercial_seller.rate_up_to_good1_seller
            commercial_seller.should be_good2_seller
          end
          it "should be able to rate to good3 seller" do
            commercial_seller.rate_up_to_good3_seller
            commercial_seller.should be_good3_seller
          end
          it "should not be able to rate to good4 seller" do
            commercial_seller.rate_up_to_good4_seller
            commercial_seller.should be_good2_seller
          end

          context "if not verified" do
            it "should have a salesvolume of 140" do
              commercial_seller.verified = false
              commercial_seller.sales_volume. should eq 140
            end
          end
          context "if verified" do
            it "should have a salesvolume of 340" do
              commercial_seller.verified = true
              commercial_seller.sales_volume. should eq 340
            end
          end
        end

        context "being a good3 seller" do
          before :each do
            commercial_seller.seller_state = "good3_seller"
          end

          it "should be able to rate to bad seller" do
            commercial_seller.rate_down_to_bad_seller
            commercial_seller.should be_bad_seller
          end
          it "should not be able to rate to standard seller" do
            commercial_seller.rate_up_to_standard_seller
            commercial_seller.should be_good3_seller
          end
          it "should not be able to rate to good1 seller" do
            commercial_seller.rate_up_to_good1_seller
            commercial_seller.should be_good3_seller
          end
          it "should not be able to rate to good2 seller" do
            commercial_seller.rate_up_to_good2_seller
            commercial_seller.should be_good3_seller
          end
          it "should be able to rate to good4 seller" do
            commercial_seller.rate_up_to_good4_seller
            commercial_seller.should be_good4_seller
          end

          context "if not verified" do
            it "should have a salesvolume of 280" do
              commercial_seller.verified = false
              commercial_seller.sales_volume. should eq 280
            end
          end
          context "if verified" do
            it "should have a salesvolume of 680" do
              commercial_seller.verified = true
              commercial_seller.sales_volume. should eq 680
            end
          end
        end

        context "being a good4 seller" do
          before :each do
            commercial_seller.seller_state = "good4_seller"
          end

          it "should be able to rate to bad seller" do
            commercial_seller.rate_down_to_bad_seller
            commercial_seller.should be_bad_seller
          end
          it "should not be able to rate to standard seller" do
            commercial_seller.rate_up_to_standard_seller
            commercial_seller.should be_good4_seller
          end
          it "should not be able to rate to good1 seller" do
            commercial_seller.rate_up_to_good1_seller
            commercial_seller.should be_good4_seller
          end
          it "should not be able to rate to good2 seller" do
            commercial_seller.rate_up_to_good2_seller
            commercial_seller.should be_good4_seller
          end
          it "should not be able to rate to good3 seller" do
            commercial_seller.rate_up_to_good3_seller
            commercial_seller.should be_good4_seller
          end

          context "if not verified" do
            it "should have a salesvolume of 560" do
              commercial_seller.verified = false
              commercial_seller.sales_volume. should eq 560
            end
          end
          context "if verified" do
            it "should have a salesvolume of 1360" do
              commercial_seller.verified = true
              commercial_seller.sales_volume. should eq 1360
            end
          end
        end

        it "should have valid commercial_seller_constants" do
          commercial_seller.commercial_seller_constants[:standard_salesvolume].should eq 35
          commercial_seller.commercial_seller_constants[:verified_bonus].should eq 50
          commercial_seller.commercial_seller_constants[:good_factor].should eq 2
          commercial_seller.commercial_seller_constants[:bad_factor].should eq 2
        end
      end
    end

    describe "buyer_states" do
      context "user being a bad buyer" do
        before :each do
          user.buyer_state = "bad_buyer"
        end

        it "should be able to rate to standard buyer" do
          user.rate_up_to_standard_buyer
          user.should be_standard_buyer
        end
        it "should not be able to rate to good buyer" do
          user.rate_up_to_good_buyer
          user.should be_bad_buyer
        end

        context "if not trusted" do
          it "should have a purchasevolume of 2" do
            user.trustcommunity = false
            user.purchase_volume. should eq 2
          end
        end
        context "if trusted" do
          it "should have a purchasevolume of 2" do
            user.trustcommunity = true
            user.purchase_volume. should eq 2
          end
        end
      end

      context "user being a standard buyer" do
        before :each do
          user.buyer_state = "standard_buyer"
        end

        it "should be able to rate to bad buyer" do
          user.rate_down_to_bad_buyer
          user.should be_bad_buyer
        end
        it "should be able to rate to good buyer" do
          user.rate_up_to_good_buyer
          user.should be_good_buyer
        end

        context "if not trusted" do
          it "should have a purchasevolume of 12" do
            user.trustcommunity = false
            user.purchase_volume. should eq 12
          end
        end
        context "if trusted" do
          it "should have a purchasevolume of 24" do
            user.trustcommunity = true
            user.purchase_volume. should eq 24
          end
        end
      end

      context "user being a good buyer" do
        before :each do
          user.buyer_state = "good_buyer"
        end

        it "should be able to rate to bad buyer" do
          user.rate_down_to_bad_buyer
          user.should be_bad_buyer
        end

        it "should not be able to rate to standard buyer" do
          user.rate_up_to_standard_buyer
          user.should be_good_buyer
        end

        context "if not trusted" do
          it "should have a purchasevolume of 24" do
            user.trustcommunity = false
            user.purchase_volume. should eq 24
          end
        end
        context "if trusted" do
          it "should have a purchasevolume of 48" do
            user.trustcommunity = true
            user.purchase_volume. should eq 48
          end
        end
      end

      it "should have valid buyer_constants" do
        user.buyer_constants[:not_registered_purchasevolume].should eq 4
        user.buyer_constants[:standard_purchasevolume].should eq 12
        user.buyer_constants[:trusted_bonus].should eq 12
        user.buyer_constants[:good_factor].should eq 2
        user.buyer_constants[:bad_factor].should eq 6
      end
    end
  end

  describe "seller rating" do
    describe PrivateUser do

      context "with positive ratings over 90%" do
        before :all do
          @private_seller = FactoryGirl::create(:private_user)
          46.times do
            FactoryGirl.create(:positive_rating, :rated_user => @private_seller)
          end
          4.times do
            FactoryGirl.create(:negative_rating, :rated_user => @private_seller)
          end
        end

        it "should change percentage of positive ratings" do
          @private_seller.update_ratings
          @private_seller.percentage_of_positive_ratings.should eq 92.0
        end
        it "should stay good seller" do
          @private_seller.seller_state = "good_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "good_seller"
        end
        it "should change from standard to good seller" do
          @private_seller.seller_state = "standard_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "good_seller"
        end
         it "should change from bad to standard seller" do
          @private_seller.seller_state = "bad_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "standard_seller"
        end
      end

      context "with positive ratings over 75%" do
        before :all do
          @private_seller = FactoryGirl::create(:private_user)
          40.times do
            FactoryGirl.create(:positive_rating, :rated_user => @private_seller)
          end
          10.times do
            FactoryGirl.create(:negative_rating, :rated_user => @private_seller)
          end
        end

        it "should change percentage of positive ratings" do
          @private_seller.update_ratings
          @private_seller.percentage_of_positive_ratings.should eq 80.0
        end
        it "should stay good seller" do
          @private_seller.seller_state = "good_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "good_seller"
        end
        it "should stay standard seller" do
          @private_seller.seller_state = "standard_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "standard_seller"
        end
         it "should change from bad to standard seller" do
          @private_seller.seller_state = "bad_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "standard_seller"
        end
      end

      context "with negative ratings over 25%" do
        before :all do
          @private_seller = FactoryGirl::create(:private_user)
          35.times do
            FactoryGirl.create(:positive_rating, :rated_user => @private_seller)
          end
          15.times do
            FactoryGirl.create(:negative_rating, :rated_user => @private_seller)
          end
        end

        it "should change percentage of negative ratings" do
          @private_seller.update_ratings
          @private_seller.percentage_of_negative_ratings.should eq 30.0
        end
        it "should change from good to bad seller" do
          @private_seller.seller_state = "good_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "bad_seller"
        end
        it "should change from standard to bad seller" do
          @private_seller.seller_state = "standard_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "bad_seller"
        end
         it "should stay bad seller" do
          @private_seller.seller_state = "bad_seller"
          @private_seller.update_ratings
          @private_seller.seller_state.should eq "bad_seller"
        end
      end

    end

    describe LegalEntity do

      context "with positive ratings over 70%" do
        before :all do
          @commercial_seller = FactoryGirl.create(:legal_entity)
          40.times do
            FactoryGirl.create(:positive_rating, :rated_user => @commercial_seller)
          end
          10.times do
            FactoryGirl.create(:negative_rating, :rated_user => @commercial_seller)
          end
        end

        it "should change percentage of positive ratings" do
          @commercial_seller.update_ratings
          @commercial_seller.percentage_of_positive_ratings.should eq 80.0
        end
        it "should stay good1 seller" do
          @commercial_seller.seller_state = "good1_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "good1_seller"
        end
        it "should stay good2 seller" do
          @commercial_seller.seller_state = "good2_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "good2_seller"
        end
        it "should stay good3 seller" do
          @commercial_seller.seller_state = "good3_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "good3_seller"
        end
        it "should stay good4 seller" do
          @commercial_seller.seller_state = "good4_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "good4_seller"
        end
        it "should stay standard seller" do
          @commercial_seller.seller_state = "standard_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "standard_seller"
        end
        it "should change from bad to standard seller" do
          @commercial_seller.seller_state = "bad_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "standard_seller"
        end
      end

      context "with negative ratings over 25%" do
        before :all do
          @commercial_seller = FactoryGirl.create(:legal_entity)
          35.times do
            FactoryGirl.create(:positive_rating, :rated_user => @commercial_seller)
          end
          15.times do
            FactoryGirl.create(:negative_rating, :rated_user => @commercial_seller)
          end
        end

        it "should change percentage of negative ratings" do
          @commercial_seller.update_ratings
          @commercial_seller.percentage_of_negative_ratings.should eq 30.0
        end
        it "should change from good1 to bad seller" do
          @commercial_seller.seller_state = "good1_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "bad_seller"
        end
        it "should change from good2 to bad seller" do
          @commercial_seller.seller_state = "good2_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "bad_seller"
        end
        it "should change from good3 to bad seller" do
          @commercial_seller.seller_state = "good3_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "bad_seller"
        end
        it "should change from good4 to bad seller" do
          @commercial_seller.seller_state = "good4_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "bad_seller"
        end
        it "should change from standard to bad seller" do
          @commercial_seller.seller_state = "standard_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "bad_seller"
        end
        it "should stay bad seller" do
          @commercial_seller.seller_state = "bad_seller"
          @commercial_seller.update_ratings
          @commercial_seller.seller_state.should eq "bad_seller"
        end
      end
    end
  end
end
