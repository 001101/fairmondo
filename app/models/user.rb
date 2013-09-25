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
class User < ActiveRecord::Base
  extend Memoist

  # Friendly_id for beautiful links
  extend FriendlyId
  friendly_id :nickname, :use => :slugged
  validates_presence_of :slug

  extend Sanitization

  # Include default devise modules. Others available are: :rememberable,
  # :token_authenticatable, :encryptable, :lockable,  and :omniauthable
  devise :database_authenticatable, :registerable, :timeoutable,
         :recoverable, :trackable, :validatable, :confirmable

  after_create :create_default_library

  # Setup accessible (or protected) attributes for your model

  def self.user_attrs
    [
      :email, :password, :password_confirmation, :remember_me, :type,
      :nickname, :forename, :surname, :privacy, :legal, :agecheck, :paypal_account,
      :invitor_id, :banned, :about_me, :bank_code, #:trustcommunity,
      :title, :country, :street, :address_suffix, :city, :zip, :phone, :mobile, :fax, :direct_debit,
      :bank_account_number, :bank_name, :bank_account_owner, :company_name,
      { image_attributes: Image.image_attrs + [:id] }
    ]
  end
  #! attr_accessible *user_attributes
  #! attr_accessible *user_attributes, :as => :admin

  auto_sanitize :nickname, :forename, :surname, :street, :address_suffix, :city
  auto_sanitize :about_me, :terms, :cancellation, :about, method: 'tiny_mce'


  # @api public
  def self.attributes_protected_by_default
    ["id"] # default is ["id","type"]
  end
  #! attr_accessible :type
  #! attr_accessible :type, :as => :admin
  #! attr_protected :admin


  attr_accessor :recaptcha, :wants_to_sell
  attr_accessor :bank_account_validation , :paypal_validation


  #Relations
  has_many :transactions, through: :articles
  has_many :articles, :dependent => :destroy # As seller
  has_many :bought_articles, through: :bought_transactions, source: :article
  has_many :bought_transactions, class_name: 'Transaction', foreign_key: 'buyer_id' # As buyer
  has_many :sold_transactions, class_name: 'Transaction', foreign_key: 'seller_id', conditions: "state = 'sold' AND type != 'MultipleFixedPriceTransaction'", inverse_of: :seller
  # has_many :bids, :dependent => :destroy
  # has_many :invitations, :dependent => :destroy

  has_many :article_templates, :dependent => :destroy
  has_many :libraries, :dependent => :destroy

  ##
  has_one :image, as: :imageable
  accepts_nested_attributes_for :image
  ##



  #belongs_to :invitor ,:class_name => 'User', :foreign_key => 'invitor_id'


  # validations

  validates_inclusion_of :type, :in => ["PrivateUser", "LegalEntity"]

  validates :forename, presence: true, on: :update
  validates :surname, presence: true, on: :update

  validates :nickname , :presence => true, :uniqueness => true

  validates :street, format: /\A.+\d+.*\z/, on: :update, unless: Proc.new {|c| c.street.blank?} # format: ensure digit for house number
  validates :address_suffix, length: { maximum: 150 }
  validates :zip, zip: true, on: :update, unless: Proc.new {|c| c.zip.blank?}


  validates :recaptcha, presence: true, acceptance: true, on: :create

  validates :privacy, :acceptance => true, :on => :create
  validates :legal, :acceptance => true, :on => :create
  validates :agecheck, :acceptance => true , :on => :create



  with_options if: :wants_to_sell? do |seller|
    seller.validates :country, :street, :city, :zip, presence: true, on: :update
    seller.validates :direct_debit, acceptance: {accept: true}, on: :update
    seller.validates :bank_code, :bank_account_number,:bank_name ,:bank_account_owner, presence: true
  end

  validates :bank_code, :numericality => {:only_integer => true}, :length => { :is => 8 }, :unless => Proc.new {|c| c.bank_code.blank?}
  validates :bank_account_number, :numericality => {:only_integer => true}, :length => { :maximum => 10}, :unless => Proc.new {|c| c.bank_account_number.blank?}
  validates :paypal_account, format: { with: /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\z/ }, :unless => Proc.new {|c| c.paypal_account.blank?}
  validates :paypal_account, presence: true, if: :paypal_validation
  validates :bank_code, :bank_account_number,:bank_name ,:bank_account_owner, presence: true, if: :bank_account_validation


  validates :about_me, :length => { :maximum => 2500 }



  # Return forename plus surname
  # @api public
  # @return [String]
  def fullname
    "#{self.forename} #{self.surname}"
  end
  # memoize :fullname

  # Return user nickname
  # @api return
  # @public [String]
  def name
    name = "#{self.nickname}"
  end

  # Compare IDs of users
  # @api public
  # @param user [User] Usually current_user
  def is? user
    user && self.id == user.id
  end

  # Check if user was created before Sept 24th 2013
  # @api public
  # @param user [User] Usually current_user
  def is_pioneer?
    self.created_at < Time.parse("2013-09-23 23:59:59.000000 CEST +02:00")
  end

  # Static method to get admin status even if current_user is nil
  # @api public
  # @param user [User, nil] Usually current_user
  def self.is_admin? user
    user && user.admin?
  end

  # Get generated customer number
  # @api public
  # @return [String] 8-digit number
  def customer_nr
    id.to_s.rjust 8, "0"
  end

  # Get url for user image
  # @api public
  # @param symbol [Symbol] which type
  # @return [String] URL
  def image_url symbol
    (img = image) ? img.image.url(symbol) : "/assets/missing.png"
  end

  # Return a formatted address
  # @api public
  # @return [String]
  def address
    "#{self.address_suffix}, #{self.street}, #{self.zip} #{self.city}"
  end


  state_machine :seller_state, :initial => :standard_seller do

    event :rate_up_to_standard_seller do
      transition :bad_seller => :standard_seller
    end

    event :rate_down_to_bad_seller do
      transition all => :bad_seller
    end

    event :block do
      transition all => :blocked
    end

    event :unblock do
      transition :blocked => :standard_seller
    end

  end

  state_machine :buyer_state, :initial => :standard_buyer do

    event :rate_up_to_good_buyer do
      transition :standard_buyer => :good_buyer
    end

    event :rate_up_to_standard_buyer do
      transition :bad_buyer => :standard_buyer
    end

    event :rate_down_to_bad_buyer do
      transition all => :bad_buyer
    end
  end

  def buyer_constants
    buyer_constants = {
      :not_registered_purchasevolume => 4,
      :standard_purchasevolume => 12,
      :trusted_bonus => 12,
      :good_factor => 2,
      :bad_factor => 6
    }
  end

  def purchase_volume
    ( bad_buyer? ? ( buyer_constants[:standard_purchasevolume] / buyer_constants[:bad_factor] ) :
    ( buyer_constants[:standard_purchasevolume] +
    ( self.trustcommunity ? buyer_constants[:trusted_bonus] : 0 ) ) *
    ( good_buyer? ? buyer_constants[:good_factor] : 1 ) )
  end

  def bank_account_exists?
    ( self.bank_code.to_s != '' ) && ( self.bank_name.to_s != '' ) && ( self.bank_account_number.to_s != '' ) && ( self.bank_account_owner.to_s != '' )
  end

  def paypal_account_exists?
    ( self.paypal_account.to_s != '' )
  end

  def can_sell?
    self.wants_to_sell = true
    can_sell = self.valid?
    self.wants_to_sell = false
    can_sell
  end

  private

  # @api private
  def create_default_library
    if self.libraries.empty?
      Library.create(name: I18n.t('library.default'), public: false, user_id: self.id)
    end
  end

  def wants_to_sell?
    self.wants_to_sell
  end

end
