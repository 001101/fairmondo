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
class WelcomeController < ApplicationController

  skip_before_filter :authenticate_user!, only: [:index, :feed, :landing]

  def index
    query_object = FeaturedLibraryQuery.new
    @queue1 = query_object.set(:queue1).find(3)
    #@queue2 = query_object.set(:queue2).find(1)
    #@queue4 = query_object.set(:queue4).find(1)
    @queue3 = query_object.set(:queue3).find(2)
    @old = query_object.set(:old).find(2)
    @donation_articles = query_object.set(:donation_articles).find(2)

    @trending_libraries = Library.trending_welcome_page.includes(user: [:image], comments: { user: [:image] })

    # Personalized section
    if user_signed_in?
      @last_hearted_libraries = current_user.hearted_libraries.
                                published.no_admins.min_elem(2).
                                includes(:user, library_elements: { article: [:images, :seller] }).
                                where('users.id != ?', current_user.id).
                                reorder('hearts.created_at DESC').limit(2)
    end
  end

  # Rss Feed
  def feed
    @articles = Article.active.limit(20)

    respond_to do |format|
      format.rss { render layout: false } #index.rss.builder
    end
  end
end
