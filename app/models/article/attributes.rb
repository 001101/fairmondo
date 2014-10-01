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
module Article::Attributes
  extend ActiveSupport::Concern

  included do
    extend Tokenize

    auto_sanitize :content, method: 'tiny_mce'
    auto_sanitize :title

    #title

    validates_presence_of :title , :content
    validates_length_of :title, :minimum => 6, :maximum => 200
    validates :content, length: { maximum: 10000, tokenizer: tokenizer_without_html }
    validates :article_template_name, uniqueness: { scope: [:seller] }, presence: true, if: Proc.new { |a| a.is_template? || a.save_as_template? }


    #conditions

    validates_presence_of :condition
    validates_presence_of :condition_extra , if: :old?
    enumerize :condition, in: [:new, :old], predicates:  true
    enumerize :condition_extra, in: [:as_good_as_new, :as_good_as_warranted ,:used_very_good , :used_good, :used_satisfying , :broken] # refs #225


    #money_rails and price
    validates :price_cents, presence: true, :numericality => { greater_than_or_equal_to: 0, less_than_or_equal_to: 1000000 }

    monetize :price_cents


    # vat (Value Added Tax)

    validates :vat , presence: true , inclusion: { in: [0,7,19] },  if: :belongs_to_legal_entity?


    validates :basic_price_cents, :numericality => { greater_than_or_equal_to: 0, less_than_or_equal_to: 1000000 } , :allow_nil => false

    monetize :basic_price_cents

    enumerize :basic_price_amount, in: [:kilogram, :gram, :liter, :milliliter, :cubicmeter, :meter, :squaremeter, :portion ]

    validates :basic_price_amount, presence: true, if: lambda {|obj| obj.basic_price_cents && obj.basic_price_cents > 0 }

    # legal entity attributes

    validates_length_of :custom_seller_identifier, maximum: 65, allow_nil: true, allow_blank: true
    validates_length_of :gtin, minimum: 8, maximum: 14, allow_nil: true, allow_blank: true

    # =========== Transport =============
    TRANSPORT_TYPES = [:type1, :type2,:pickup]

    auto_sanitize :transport_type1_provider, :transport_type2_provider, :transport_details
    auto_sanitize :transport_time, remove_all_spaces: true

    validates :transport_type1_provider, :length => { :maximum => 255 }
    validates :transport_type2_provider, :length => { :maximum => 255 }

    validates :transport_type1_price, :transport_type1_provider, :presence => true ,:if => :transport_type1
    validates :transport_type2_price, :transport_type2_provider, :presence => true ,:if => :transport_type2

    validates :transport_type1_number, numericality: { greater_than: 0 }
    validates :transport_type2_number, numericality: { greater_than: 0 }

    validates :transport_details, :length => { :maximum => 2500 }

    validates :transport_time, length: { maximum: 7 }, format: { with: /\A\d{1,2}-?\d{,2}\z/ }, allow_blank: true

    monetize :transport_type2_price_cents, :numericality => { :greater_than_or_equal_to => 0, :less_than_or_equal_to => 50000 }, :allow_nil => true
    monetize :transport_type1_price_cents, :numericality => { :greater_than_or_equal_to => 0, :less_than_or_equal_to => 50000 }, :allow_nil => true

    validate :transport_method_checked

    # ================ Payment ====================
    PAYMENT_TYPES = [:bank_transfer, :cash, :paypal, :cash_on_delivery, :invoice]

    #payment

    auto_sanitize :payment_details

    validates :payment_cash_on_delivery_price, :presence => true ,:if => :payment_cash_on_delivery

    before_validation :set_sellers_nested_validations

    monetize :payment_cash_on_delivery_price_cents, :numericality => { :greater_than_or_equal_to => 0, :less_than_or_equal_to => 50000 }, :allow_nil => true

    validates :payment_details, length: { :maximum => 2500 }

    validate :bank_account_exists, :if => :payment_bank_transfer
    validate :bank_transfer_available, :if => :payment_bank_transfer
    validate :paypal_account_exists, :if => :payment_paypal

    validates_presence_of :quantity

    validates_numericality_of :quantity, :greater_than_or_equal_to => 1, :less_than_or_equal_to => 10000
    validates_numericality_of :quantity_available, greater_than_or_equal_to: 0, less_than_or_equal_to: 10000

    validate :payment_method_checked


    ### ACTIVATE ###
    attr_accessor :tos_accepted, :changing_state
    validates :tos_accepted, acceptance: true, presence: true, on: :update, if: :changing_state
  end



  def set_sellers_nested_validations
    seller.bank_account_validation = true if payment_bank_transfer
    seller.paypal_validation = true if payment_paypal
  end

  def belongs_to_legal_entity?
    self.seller.is_a?(LegalEntity)
  end


  def transport_details_for type
    case type
    when :type1
      [self.transport_type1_price, self.transport_type1_number]
    when :type2
      [self.transport_type2_price, self.transport_type2_number]
    else
      [Money.new(0),0]
    end
  end

  def transport_provider transport
    case transport
    when 'pickup'
      I18n.t('enumerize.business_transaction.selected_transport.pickup')
    when 'type1'
      self.transport_type1_provider
    when 'type2'
      self.transport_type2_provider
    end
  end

  # Returns an array with all selected transport types.
  # Default transport will be the first element.
  #
  # @api public
  # @return [Array] An array with selected transport types.
  def selectable_transports
    selectable "transport"
  end

  # Returns an array with all selected payment types.
  # Default payment will be the first element.
  #
  # @api public
  # @return [Array] An array with selected payment types.
  def selectable_payments
    selectable "payment"
  end

  private
    def transport_method_checked
      unless self.transport_pickup || self.transport_type1 || self.transport_type2
        errors.add(:transport_details, I18n.t("article.form.errors.invalid_transport_option"))
      end
    end

    def payment_method_checked
      unless self.payment_bank_transfer || self.payment_paypal || self.payment_cash || self.payment_cash_on_delivery || self.payment_invoice
        errors.add(:payment_details, I18n.t("article.form.errors.invalid_payment_option"))
      end
    end

    # DRY method for selectable_transports and selectable_payments
    #
    # @api private
    # @return [Array] An array with selected attribute types
    def selectable attribute
      # Get all selected attributes
      output = []
      eval("#{attribute.upcase}_TYPES").each do |e|
        output << e.to_s if self.send "#{attribute}_#{e}"
      end
      output
    end

    def bank_account_exists
      unless self.seller.bank_account_exists?
        errors.add(:payment_bank_transfer, I18n.t("article.form.errors.bank_details_missing"))
      end
    end

    def paypal_account_exists
      unless self.seller.paypal_account_exists?
        errors.add(:payment_paypal, I18n.t("article.form.errors.paypal_details_missing"))
      end
    end

    def bank_transfer_available
      if self.seller.created_at > 1.month.ago && self.price_cents >= 10000 && self.seller.type == 'PrivateUser'
        errors.add(:payment_bank_transfer, I18n.t('article.form.errors.bank_transfer_not_allowed'))
      end
    end
end
