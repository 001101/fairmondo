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
class Article < ActiveRecord::Base
  extend Enumerize
  #! attr_accessible

  # Friendly_id for beautiful links
  extend FriendlyId
  friendly_id :title, :use => :slugged
  validates_presence_of :slug unless :template?

  #only generate friendly slug if we dont have a template
  def should_generate_new_friendly_id?
    !template?
  end

  delegate :terms, :cancellation, :about, :country , :to => :seller, :prefix => true
  delegate :quantity_available, to: :transaction, prefix: true

  # Relations
  has_one :transaction, conditions: "type != 'PartialFixedPriceTransaction'", dependent: :destroy, inverse_of: :article
  has_many :partial_transactions, class_name: 'PartialFixedPriceTransaction', conditions: "type = 'PartialFixedPriceTransaction'", inverse_of: :article
  accepts_nested_attributes_for :transaction
  # validates_presence_of :transaction

  has_many :library_elements, :dependent => :destroy
  has_many :libraries, through: :library_elements

  belongs_to :seller, class_name: 'User', foreign_key: 'user_id'
  validates_presence_of :user_id

  belongs_to :article_template

  has_many :invoice_items
  has_many :invoices, :through => :invoice_items

  # Misc mixins
  extend Sanitization
  # Article module concerns
  include Categories, Commendation, FeesAndDonations, Images, BuildTransaction, Attributes, Search, Template, State, Scopes

  def images_attributes=(attributes)
    self.images.clear
    attributes.each_key do |key|
      if attributes[key].has_key? :id
        unless attributes[key][:_destroy] == "1"
           image = Image.find(attributes[key][:id])
           image.image = attributes[key][:image] if attributes[key].has_key? :image # updated the image itself
           image.is_title = attributes[key][:is_title]
           self.images << image
        end

      else
        self.images << Image.new(attributes[key]) if attributes[key][:image] != nil
      end
    end
  end

  amoeba do
    enable
    include_field :fair_trust_questionnaire
    include_field :social_producer_questionnaire
    include_field :categories
    nullify :slug
    nullify :article_template_id
    customize lambda { |original_article, new_article|
      original_article.images.each do |image|
        copyimage = Image.new
        copyimage.image = image.image
        copyimage.is_title = image.is_title
        new_article.images << copyimage
        copyimage.save
      end
    }
  end

  # Does this article belong to user X?
  # @api public
  # param user [User] usually current_user
  def owned_by? user
    user && self.seller.id == user.id
  end

  # for featured article
  def profile_name
    if self.seller.type == "PrivateUser"
      self.seller.nickname
    else
      "#{self.seller.nickname}, #{self.seller.city}"
    end
  end

  def self.article_attrs with_nested_template = true
    (
      Article.common_attrs + Article.money_attrs + Article.payment_attrs +
      Article.basic_price_attrs + Article.transport_attrs +
      Article.category_attrs + Article.commendation_attrs +
      Article.image_attrs + Article.fee_attrs +
      Article.template_attrs(with_nested_template) +
      Article.legal_entity_attrs
    )
  end

  def self.export_articles(user, params = nil)
    # bugbug The horror...

    if params == "active"
      articles = user.articles.where(:state => "active")
    elsif params == "preview"
      articles = user.articles.where(:state => "preview")
    else
      articles = user.articles
    end

    header_row = ["title", "categories", "condition", "condition_extra",
                  "content", "quantity", "price_cents", "basic_price_cents",
                  "basic_price_amount", "vat", "title_image_url", "image_2_url",
                  "transport_pickup", "transport_type1",
                  "transport_type1_provider", "transport_type1_price_cents",
                  "transport_type2", "transport_type2_provider",
                  "transport_type2_price_cents", "transport_details",
                  "payment_bank_transfer", "payment_cash", "payment_paypal",
                  "payment_cash_on_delivery",
                  "payment_cash_on_delivery_price_cents", "payment_invoice",
                  "payment_details", "fair_kind", "fair_seal", "support",
                  "support_checkboxes", "support_other", "support_explanation",
                  "labor_conditions", "labor_conditions_checkboxes",
                  "labor_conditions_other", "labor_conditions_explanation",
                  "environment_protection", "environment_protection_checkboxes",
                  "environment_protection_other",
                  "environment_protection_explanation", "controlling",
                  "controlling_checkboxes", "controlling_other",
                  "controlling_explanation", "awareness_raising",
                  "awareness_raising_checkboxes", "awareness_raising_other",
                  "awareness_raising_explanation", "nonprofit_association",
                  "nonprofit_association_checkboxes",
                  "social_businesses_muhammad_yunus",
                  "social_businesses_muhammad_yunus_checkboxes",
                  "social_entrepreneur", "social_entrepreneur_checkboxes",
                  "social_entrepreneur_explanation", "ecologic_seal",
                  "upcycling_reason", "small_and_precious_eu_small_enterprise",
                  "small_and_precious_reason", "small_and_precious_handmade",
                  "gtin", "custom_seller_identifier"]

    def self.create_fair_attributes(article, header_row)
      fair_attributes_raw_array = []
      fair_attributes = []
      if article.fair_trust_questionnaire
        fair_attributes_raw_array = article.fair_trust_questionnaire.attributes.values_at(*header_row[29..48])
        fair_attributes_raw_array.each do |element|
          if element.class == Array
            fair_attributes << element.join(',')
          else
            fair_attributes << element
          end
        end
      else
        20.times do
          fair_attributes << nil
        end
      end
      fair_attributes
    end

    def self.create_social_attributes(article, header_row)
      social_attributes_raw_array = []
      social_attributes = []
      if article.social_producer_questionnaire
        social_attributes_raw_array = article.social_producer_questionnaire.attributes.values_at(*header_row[49..55])
        social_attributes_raw_array.each do |element|
          if element.class == Array
            social_attributes << element.join(',')
          else
            social_attributes << element
          end
        end
      else
        7.times do
          social_attributes << nil
        end
      end
      social_attributes
    end


    CSV.generate(:col_sep => ";") do |csv|
      # bugbug Refactor asap
      csv << header_row
      articles.reverse_order.each do |article|
        csv << article.attributes.values_at("title") +
        [article.categories.map { |a| a.id }.join(",")] +
        article.attributes.values_at(*header_row[2..9]) +
        article.provide_external_urls +
        article.attributes.values_at(*header_row[12..28]) +
        create_fair_attributes(article, header_row) +
        create_social_attributes(article, header_row) +
        article.attributes.values_at(*header_row[56..-1])
      end
      csv.string.gsub! "\"", ""
    end
  end

  def is_conventional?
    self.condition == "new" && !self.fair && !self.small_and_precious && !self.ecologic
  end

  def is_available?
    self.transaction_quantity_available == 0
  end

  #has_many :buyer, through: :transaction, class_name: 'User', foreign_key: 'buyer_id', source: :article
  def buyer
    if self.transaction.multiple?
      self.partial_transactions.map { |e| e.buyer }
    else
      Array.new << self.transaction.buyer
    end
  end

  def provide_external_urls
    external_urls = []
    unless self.images.empty?
      self.images.each do |image|
        external_urls << image.external_url
        break if external_urls.length == 2
      end
    end
    until external_urls.length == 2
      external_urls << nil
    end
    external_urls
  end
end
