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
### SimpleCOV ###

require 'simplecov'
require 'coveralls'
require 'simplecov-json'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter,
  SimpleCov::Formatter::JSONFormatter
]

SimpleCov.start 'rails' do
  add_filter "app/mailers/notification.rb"
  add_filter "gems/*"
  add_filter "lib/tasks/*"
  add_filter "app/jobs/process_mass_upload_job.rb"
  add_filter "app/models/statistic.rb"
  add_filter "app/helpers/statistic_helper.rb"
  add_filter "lib/autoload/sidekiq_redis_connection_wrapper.rb"
  add_filter "lib/autoload/paperclip_orphan_file_cleaner.rb"
  add_filter "lib/autoload/inherited_resources.rb"
  add_filter "lib/autoload/paypal_ipn.rb"
  minimum_coverage 100
end
