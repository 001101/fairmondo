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
if Rails.env.development?
  Dir.entries("#{Rails.root}/app/models/users").each do |c|
    require_dependency File.join("app","models", "users", "#{c}") if c =~ /.rb$/
  end
  Dir.entries("#{Rails.root}/app/models/images").each do |c|
    require_dependency File.join("app","models", "images", "#{c}") if c =~ /.rb$/
  end
  ActionDispatch::Reloader.to_prepare do
    Dir.entries("#{Rails.root}/app/models/users").each do |c|
      require_dependency File.join("app","models", "users", "#{c}") if c =~ /.rb$/
    end
    Dir.entries("#{Rails.root}/app/models/images").each do |c|
      require_dependency File.join("app","models", "images", "#{c}") if c =~ /.rb$/
    end
  end
end


