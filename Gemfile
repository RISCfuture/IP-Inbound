# frozen_string_literal: true

source "https://rubygems.org"


gem 'fastlane'
gem 'nkf'
gem 'abbrev'
gem 'logger'
gem 'mutex_m'
gem 'csv'
gem 'ostruct'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
