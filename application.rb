require "action_controller/railtie"
require "action_cable/engine"
require "active_model"
require "active_record"
require "nulldb/rails"
require "rails/command"
require "rails/commands/server/server_command"
require "cable_ready"
require "stimulus_reflex"
require_relative "./base_filter"
require_relative "./book"
require_relative "./restaurant"

module ApplicationCable; end

class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :session_id

  def connect
    self.session_id = request.session.id
  end  
end

class ApplicationCable::Channel < ActionCable::Channel::Base; end

class ApplicationController < ActionController::Base; end

class ApplicationReflex < StimulusReflex::Reflex; end

module Filterable
  extend ActiveSupport::Concern
  # include StimulusReflex::ConcernEnhancer

  included do
    if respond_to?(:helper_method)
      helper_method :filter_active_for?
      helper_method :filter_for
    end
  end

  def filter_active_for?(resource, attribute, value=true)
    filter = filter_for(resource)

    filter.active_for?(attribute, value)
  end

  private

  def filter_for(resource)
    "#{resource}Filter".constantize.new(session)
  end

  def set_filter_for!(resource, param, value)
    filter_for(resource).merge!(param, value)
  end
end

class FilterReflex < ApplicationReflex
  include Filterable
  
  def filter
    resource, param = element.dataset.to_h.fetch_values(:resource, :param)
    value = if element["type"] == "checkbox"
      element.checked
    else 
      element.dataset.value || element.value
    end

    set_filter_for!(resource, param, value)
  end
end

class DemosController < ApplicationController
  include Filterable

  def show
    @books = Book.all
    @books = filter_for("Book").apply!(@books)
    
    @restaurants = Restaurant.all
    @restaurants = filter_for("Restaurant").apply!(@restaurants)
    render inline: <<~HTML
      <html>
        <head>
          <title>Filterable Reflex</title>
          <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.0-beta2/dist/css/bootstrap.min.css" rel="stylesheet">
          <%= javascript_include_tag "/index.js", type: "module" %>
        </head>
        <body>
          <div class="container my-5">
            <h1>Filterable</h1>
            
            <h2 class="mt-4">Books</h2>
            
            <input type="text" class="form-control" id="book_query" placeholder="Search for author or title" data-reflex="input->Filter#filter" data-resource="Book" data-param="query" data-reflex-root="#books-table"/>
            
            <table class="table" id="books-table">
              <thead>
                <tr>
                  <th scope="col">Author</th>
                  <th scope="col">Title</th>
                </tr>
              </thead>
              <tbody>
                <% @books.each do |book| %>
                  <tr>
                    <td><%= book.author %></td>
                    <td><%= book.title %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            
            <h2 class="mt-8">Restaurants</h2>
            
            <div class="row row-cols-lg-auto g-3 align-items-center">
              <div class="col-12">
                <input type="text" class="form-control" id="restaurants_query" placeholder="Search for a name" data-reflex="input->Filter#filter" data-resource="Restaurant" data-param="query" data-reflex-root="#restaurants-table"/>
              </div>
              <div class="col-12">
                <select class="form-select" id="restaurant-rating" aria-label="Restaurant Rating" data-reflex="change->FilterReflex#filter" data-resource="Restaurant" data-param="rating" data-reflex-root="#restaurants-table">
                  <option value="1" selected>All Ratings</option>
                  <option value="2">>= 2</option>
                  <option value="3">>= 3</option>
                  <option value="4">>= 4</option>
                  <option value="5">>= 5</option>
                </select>
              </div>
              <div class="col-12">
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" id="restaurant-open" data-reflex="change->FilterReflex#filter" data-resource="Restaurant" data-param="open_now" data-reflex-root="#restaurants-table">
                  <label class="form-check-label" for="restaurant-open">
                    now open (UTC)
                  </label>
                </div>
              </div>
            </div>
            
            <table class="table" id="restaurants-table">
              <thead>
                <tr>
                  <th scope="col">Name</th>
                  <th scope="col">Rating</th>
                  <th scope="col">Opening Hours</th>
                </tr>
              </thead>
              <tbody>
                <% @restaurants.each do |restaurant| %>
                  <tr>
                    <td><%= restaurant.name %></td>
                    <td><%= restaurant.rating %></td>
                    <td><%= restaurant.opening_hours %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </body>
      </html>
    HTML
  end
end

class MiniApp < Rails::Application
  require "stimulus_reflex/../../app/channels/stimulus_reflex/channel"

  config.action_controller.perform_caching = true
  config.consider_all_requests_local = true
  config.public_file_server.enabled = true
  config.secret_key_base = "cde22ece34fdd96d8c72ab3e5c17ac86"
  config.secret_token = "bf56dfbbe596131bfca591d1d9ed2021"
  config.session_store :cache_store
  config.hosts.clear

  Rails.cache = ActiveSupport::Cache::RedisCacheStore.new(url: "redis://localhost:6379/1")
  Rails.logger = ActionCable.server.config.logger = Logger.new($stdout)
  ActionCable.server.config.cable = {"adapter" => "redis", "url" => "redis://localhost:6379/1"}

  routes.draw do
    mount ActionCable.server => "/cable"
    get '___glitch_loading_status___', to: redirect('/')
    resource :demo, only: :show
    root "demos#show"
  end
end

ActiveRecord::Base.establish_connection adapter: :nulldb, schema: "schema.rb"

Rails::Server.new(app: MiniApp, Host: "0.0.0.0", Port: ARGV[0]).start
