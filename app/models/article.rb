#
#
# == License:
# Fairmondo - Fairmondo is an open-source online marketplace.
# Copyright (C) 2013 Fairmondo eG
#
# This file is part of Fairmondo.
#
# Fairmondo is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Fairmondo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Fairmondo.  If not, see <http://www.gnu.org/licenses/>.
#
class Article < ActiveRecord::Base
  extend Enumerize
  extend FriendlyId
  include Commentable

  # Friendly_id for beautiful links
  def slug_candidates
    [
      :title,
      [:title, :seller_nickname],
      [:title, :seller_nickname, :created_at ]
    ]
  end

  friendly_id :slug_candidates, :use => [:slugged, :finders]

  # Action attribute: c/create/u/update/d/delete - for export and csv upload
  # keep_images attribute: see edit_as_new
  attr_accessor :action, :keep_images, :save_as_template

  attr_writer :article_search_form #find a way to remove this! arcane won't like it

  validates_presence_of :slug unless :template?

  delegate :id, :terms, :cancellation, :about, :country, :ngo, :nickname, :email,
           :vacationing?, :free_transport_available, :free_transport_at_price,
           :to => :seller, :prefix => true
  delegate :nickname, to: :friendly_percent_organisation, prefix: true, allow_nil: true


  # Relations
  has_many :business_transactions, inverse_of: :article
  has_many :line_items, inverse_of: :article

  has_many :library_elements, :dependent => :destroy
  has_many :libraries, through: :library_elements

  belongs_to :seller, class_name: 'User', foreign_key: 'user_id'
  alias_method :user, :seller
  alias_method :user=, :seller=

  belongs_to :original, class_name: 'Article', foreign_key: 'original_id' # the article that this article is a copy of, if applicable

  has_many :mass_upload_articles
  has_many :mass_uploads, through: :mass_upload_articles

  belongs_to :friendly_percent_organisation, class_name: 'User', foreign_key: 'friendly_percent_organisation_id'
  belongs_to :discount

  validates_presence_of :user_id

  # Misc mixins
  extend Sanitization
  # Article module concerns
  include Categories, Commendation, FeesAndDonations,
          Images, Attributes, State, Scopes,
          Checks, Discountable

  # Elastic

  include Tire::Model::Search

  settings Indexer.settings do
    mapping :_source => { :excludes => ['content'] } do
      indexes :id,           :index => :not_analyzed
      indexes :title,  type: 'multi_field'  , :fields => {
         :search => { type: 'string', analyzer: "decomp_stem_analyzer"},
         :decomp => { type: 'string', analyzer: "decomp_analyzer"},
      }
      indexes :content,      analyzer: "decomp_stem_analyzer"
      indexes :gtin,         :index    => :not_analyzed

      # filters

      indexes :fair, :type => 'boolean'
      indexes :ecologic, :type => 'boolean'
      indexes :small_and_precious, :type => 'boolean'
      indexes :swappable, :type => 'boolean'
      indexes :borrowable, :type => 'boolean'
      indexes :condition
      indexes :categories, :as => Proc.new { self.categories.map{|c| c.self_and_ancestors.map(&:id) }.flatten  }


      # sorting
      indexes :created_at, :type => 'date'

      # stored attributes

      indexes :slug
      indexes :title_image_url_thumb, :as => 'title_image_url_thumb'
      indexes :price, :as => 'price_cents', :type => 'long'
      indexes :basic_price, :as => 'basic_price_cents', :type => 'long'
      indexes :basic_price_amount
      indexes :vat, :type => 'long'

      indexes :friendly_percent, :type => 'long'
      indexes :friendly_percent_organisation , :as => 'friendly_percent_organisation_id'
      indexes :friendly_percent_organisation_nickname, :as => Proc.new { friendly_percent_organisation ? self.friendly_percent_organisation_nickname : nil }

      indexes :transport_pickup
      indexes :zip, :as => Proc.new { self.seller.standard_address_zip if self.transport_pickup || self.seller.is_a?(LegalEntity) }

      # seller attributes
      indexes :belongs_to_legal_entity? , :as => 'belongs_to_legal_entity?'
      indexes :seller_ngo, :as => 'seller_ngo'
      indexes :seller_nickname, :as => 'seller_nickname'
      indexes :seller, :as => 'seller.id'


    end
  end

  # ATTENTION DO NOT CALL THIS WITHOUT A TRANSACTION (See Cart#buy)
  def buy! value
    self.quantity_available -= value
    if self.quantity_available < 1
      self.remove_from_libraries
      self.state = "sold"
    end
    self.save! # validation is performed on the attribute
  end

  def quantity_available_with_article_state
    self.active? ? quantity_available_without_article_state : 0
  end

  def quantity_available
    super || self.quantity
  end

  alias_method_chain :quantity_available, :article_state

  def save_as_template?
    self.save_as_template == "1"
  end

  def images_attributes=(attributes)
    self.images.clear
    attributes.each do |key,image_attributes|
      if image_attributes.has_key? :id
        self.images << update_existing_image(image_attributes) unless image_attributes[:_destroy] == "1"
      else
        self.images << ArticleImage.new(image_attributes) if image_attributes[:image] != nil
      end
    end
  end

  def update_existing_image image_attributes
    image = Image.find(image_attributes[:id])
    image.image = image_attributes[:image] if image_attributes.has_key? :image # updated the image itself
    image.is_title = image_attributes[:is_title]
  end

  def self.edit_as_new article
    new_article = article.amoeba_dup
    new_article.state = "preview"
    new_article
  end

  amoeba do
    enable
    include_field :fair_trust_questionnaire
    include_field :social_producer_questionnaire
    customize lambda { |original_article, new_article|
      new_article.categories = original_article.categories

      # move images to new article
      original_article.images.each do |image|
        if original_article.keep_images
          image.imageable_id = nil
          new_article.images << image
          image.save
        else
          begin
            copyimage = ArticleImage.new
            copyimage.image = image.image
            copyimage.is_title = image.is_title
            copyimage.external_url = image.external_url
            new_article.images << copyimage
            copyimage.save
          rescue
          end
        end
      end

      # unset slug on templates
      if original_article.is_template? || original_article.save_as_template? # cloned because of template handling
        new_article.slug = nil
      else # cloned because of edit_as_new
        new_article.original_id = original_article.id # will be used in after_create; see observer
      end
    }
  end

  def should_generate_new_friendly_id?
    super && slug == nil
  end


  def is_template?
    # works even when the db state did not change yet
    self.state.to_sym == :template
  end



end
