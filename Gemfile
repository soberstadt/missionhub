source 'https://rubygems.org'
gem "default_value_for"
gem "devise", '~> 2.1.0' #, git: "git://github.com/plataformatec/devise.git"
gem "paperclip", :git => 'git://github.com/thoughtbot/paperclip.git'
gem "ransack", :git => "git://github.com/ernie/ransack.git", ref: 'c7c4e46dc19fe6f755183a6da39fcb82a265ed10'
gem "state_machine"
gem "strip_attributes"
gem 'active_model_serializers'#, git: 'git://github.com/josevalim/active_model_serializers.git'
gem 'activeadmin', '~> 0.4.4' #, git: 'git://github.com/gregbell/active_admin.git'
gem 'acts_as_list'
gem 'airbrake'
gem 'ancestry', git: 'git://github.com/stefankroes/ancestry.git'
gem 'aws-sdk', '1.8.1.3'
gem 'bitly'
gem 'bluepill', '0.0.60', require: false
gem 'cancan'
gem 'capistrano'
gem 'carmen', git: 'git://github.com/twinge/carmen.git'
gem 'client_side_validations'
gem 'coffee-script'
gem 'copycopter_client'
gem 'crack'
gem 'dalli'
gem 'deadlock_retry'
gem 'delegate_presenter'
gem 'dynamic_form'
gem 'enforce_schema_rules'
gem 'foreigner'
gem 'http_accept_language'
gem 'i18n-js', git: 'git://github.com/fnando/i18n-js.git'     # allow i18n on js files
gem 'jquery-rails'
gem 'kaminari'
gem 'libv8', '=3.11.8.17'
gem 'mini_fb'
gem 'mysql2', '~> 0.3.11'
gem 'newrelic_rpm', '>= 3.5.3.25'
gem 'nokogiri'
gem 'oj'
gem 'omniauth', '~> 1.1.1'
gem 'omniauth-facebook', '1.4.0'
gem 'paper_trail', '~> 2'
gem 'rack-offline'
gem 'rails', '3.2.13'
gem 'rails_autolink'
gem 'redis'
gem 'resque', '~> 1.20.0'
gem 'resque_mail_queue'
gem 'rest-client'                                     # to make FB api requests
gem 'retryable-rb'
#gem 'rubycas-client', '~> 2.2.1'
#gem 'rubycas-client-rails', '~> 0.1.0'
gem 'sass'
gem 'sass-rails', "~>3.2.3"
gem 'trumant-rack-oauth2-server', git: 'git://github.com/twinge/rack-oauth2-server.git', branch: 'active_record'
gem 'twilio-rb', git: 'git://github.com/stevegraham/twilio-rb.git', ref: 'fad1e27e2e3a3df84f6c15a42e1eab1c69deae7b'
gem 'unicorn'
gem 'valium'
gem 'versionist', '~> 1.0.0'
gem 'vpim', git: 'git://github.com/twinge/vpim.git'   # vcard maker
gem 'whenever'
gem 'wiser_date', '~> 0.3.0'
gem 'infobase'


group :development, :test do
  gem 'guard'
  gem 'guard-test'
  gem 'awesome_print'
  gem 'quiet_assets'
end

group :test do
  gem 'webmock'#, '= 1.8.3'
  gem 'factory_girl','~> 2.0.0.rc4'
  gem 'simplecov', '>= 0.3.5', require: false
  # gem 'ZenTest', '= 4.8.3'
  # gem 'autotest-rails'
  gem 'resque_unit'
  gem 'shoulda', :require => false
  gem 'mocha', :require => false
  gem 'ffaker'
end

group :development do
  #gem 'rails-dev-tweaks'
  gem 'rails-footnotes'
  gem 'bullet'
  gem 'travis-lint'
  gem 'mailcatcher'
  gem 'railroady'
  #gem 'localeapp'
  gem "better_errors", ">= 0.7.2"
  #gem "binding_of_caller"
end

group :performance do
  gem 'ruby-prof'
end

# Gems used only for assets and not required
# in production environments by default.
#gem 'sass-rails', "  ~> 3.1.0"
group :assets do
  gem 'therubyracer'
  gem 'coffee-rails', "~> 3.2.1"
  gem 'uglifier', ">= 1.0.3"
end

group :capistrano do
  # Shared capistrano recipes
  #gem 'pd-cap-recipes', :git => 'git://github.com/PagerDuty/pd-cap-recipes.git'

  # extra dependencies for some tasks
  #gem 'git', '1.2.5'
  #gem 'cap_gun'
  #gem 'grit'
end
