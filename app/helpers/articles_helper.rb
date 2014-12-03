# encoding: utf-8
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
module ArticlesHelper


  # Conditions
  def condition_label article
    condition_text = t("enumerize.article.condition.#{article.condition}")
    "<span class=\"Tag Tag--gray\">#{condition_text}</span>".html_safe
  end

  # Build title string
  def index_title_for search_cache
    attribute_list = ::HumanLanguageList.new
    attribute_list << t('article.show.title.new') if search_cache.condition == 'new'
    attribute_list << t('article.show.title.old') if search_cache.condition == 'old'
    attribute_list << t('article.show.title.fair') if search_cache.fair
    attribute_list << t('article.show.title.ecologic') if search_cache.ecologic
    attribute_list << t('article.show.title.small_and_precious') if search_cache.small_and_precious

    output = attribute_list.concatenate.capitalize + ' '
    output += search_cache.searched_category.name + ' ' if search_cache.searched_category

    output += t('article.show.title.article')
  end

  def breadcrumbs_for category
    output = ''
    category.self_and_ancestors.each do |c|
      last = c == category
      output += '<span>'
      output += "<a href='#{category_path(c)}' class='#{(last ? 'last' : nil )}'>"
      output += c.name
      output += '</a>'
      output += '</span>'
      output += ' > ' unless last
    end

    output
  end

  def transport_format_for method
    type = "transport"
    options_format_for type, method, true
  end

  def payment_format_for method
    type = "payment"
    options_format_for type, method
  end

  def options_format_for type, method, check_free_transport = false
    if resource.send("#{type}_#{method}")
      html = '<li>'

      if method == 'type1' || method == 'type2'
        html << resource.send("#{type}_#{method}_provider")
      else
        html << t("formtastic.labels.article.#{type}_#{method}")
      end

      price_method = "#{type}_#{method}_price"

      if (check_free_transport && resource.seller.free_transport_available && resource.seller_free_transport_at_price <= resource.price && !resource.transport_bike_courier) || !resource.respond_to?(price_method.to_sym)
        html << ' (kostenfrei)'
      else
        html << " zzgl. #{humanized_money_with_symbol(resource.send(price_method))}"
      end

      if type == 'transport' && method == 'pickup'
        html << ", <br/>PLZ: #{resource.seller.standard_address_zip}"
      end

      # TODO include into upper if statement
      if type == 'transport' && method == 'bike_courier'
        html << " zzgl. 8,00€ bei Lieferung"
      end

      html << '</li>'
      html.html_safe
    end
  end

  def default_organisation_from organisation_list
    begin
      organisation = default_form_value('friendly_percent_organisation', resource)
      default_organisation = organisation_list.select { |o| o.nickname == organisation.nickname }
      default_organisation[0] ? default_organisation[0].id : nil
    rescue
      nil
    end
  end

  # Returns true if the basic price should be shown to users
  #
  # @return Boolean
  def show_basic_price_for? article
    article.belongs_to_legal_entity? && article.basic_price_amount && article.basic_price && article.basic_price > 0
  end

  # Returns true if the friendly_percent should be shown
  #
  # @return Boolean
  def show_friendly_percent_for? article
    article.friendly_percent && article.friendly_percent > 0 && article.friendly_percent_organisation && !article.seller_ngo
  end

  def show_fair_percent_for? article
    # for german book price agreement
    # we can't be sure if the book is german
    # so we dont show fair percent on all new books
    # book category is written in exceptions.yml
    !article.could_be_book_price_agreement? && article.friendly_percent != 100
  end

  #def export_time_ranges
  #  # specify time range in months
  #  ['all', '1', '3', '6', '12']
  #end
end
