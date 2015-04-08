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
class LibraryElement < ActiveRecord::Base

  delegate :name, :user_id , to: :library , prefix: true
  delegate :title, to: :article_reduced, prefix: true

  # Validations
  validates :library_id, uniqueness: { scope: :article_id }
  validates :library_id, presence: true

  # Relations
  belongs_to :article
  belongs_to :article_reduced, ->(_o) { reduced }, class_name: 'Article', foreign_key: 'article_id'
  belongs_to :library, counter_cache: true
  has_one :user, through: :library

  scope :active, -> { where.not(inactive: true) }
  # Scopes
  default_scope -> { order(created_at: :desc) }
end
