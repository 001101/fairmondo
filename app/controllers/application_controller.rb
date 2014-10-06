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
class ApplicationController < ActionController::Base

  ## Global security
  before_filter :authenticate_user!

  ## Global actions
  before_filter :unset_cart

  # Arcane
  include Arcane

  # Pundit
  include Pundit
  after_filter :verify_authorized_with_exceptions, except: [:index, :feed]

  include BrowsingHistory # (lib/autoload) browsing history for redirects and feedback
  after_filter :store_location

  protect_from_forgery

  helper :all

  # Customize the Devise after_sign_in_path_for() for redirect to previous page after login
  def after_sign_in_path_for resource_or_scope
    if resource_or_scope.is_a?(User) && resource_or_scope.banned?
      sign_out resource_or_scope
      flash.discard
      "/banned"
    elsif request.xhr? # AJAX request
      toolbox_reload_path
    else
      stored_location_for(resource_or_scope) || redirect_back_location || user_path(resource_or_scope)
    end
  end

  protected



    # Pundit checker

    def verify_authorized_with_exceptions
      verify_authorized unless pundit_unverified_controller
    end

    def pundit_unverified_controller
      (pundit_unverified_modules.include? self.class.name.split("::").first) || (pundit_unverified_classes.include? self.class.name)
    end

    def pundit_unverified_modules
      ["Devise","RailsAdmin"]
    end

    def pundit_unverified_classes
      [
       "RegistrationsController", "SessionsController", "ToolboxController",
       "BankDetailsController", "ExportsController", "WelcomeController",
       "CategoriesController", "Peek::ResultsController", "StyleguidesController",
       "RemoteValidationsController", "BusinessTransactionsController"
      ]
    end

    def build_search_cache
      search_params = {}
      form_search_params = params.for(ArticleSearchForm)[:article_search_form]
      search_params.merge!(form_search_params) if form_search_params.is_a?(Hash)
      @search_cache = ArticleSearchForm.new(search_params)
    end

    # Caching security: Set response headers to prevent caching
    # @api semipublic
    # @return [undefined]
    def dont_cache
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    end

    # If user wants to sell
    def ensure_complete_profile
      # Check if the user has filled all fields
      unless current_user.can_sell?
        flash[:error] = t('article.notices.incomplete_profile')
        redirect_to edit_user_registration_path(incomplete_profile: true)
      end
    end

    def check_value_of_goods
      current_user.count_value_of_goods
      if current_user.value_of_goods_cents > ( current_user.max_value_of_goods_cents + current_user.max_value_of_goods_cents_bonus )
        flash[:error] = I18n.t('article.notices.max_limit')
        redirect_to user_path(current_user)
      end
    end

    def render_css_from_controller controller
      @controller_specific_css = controller
    end

    def unset_cart
      # gets called on every page load. when a session has expired, the old cart cookie needs to be cleared
      if !current_user && cookies[:cart] && !view_context.current_cart
        # if no user is logged in and there is a cart cookie but that cart can't be found / wasn't allowed
        cookies.delete :cart
      end
    end
end
