require "time"

# mimicks an ActiveRecord scope
module RestaurantRefinements
  refine Array do
    def search(query)
      filter do |restaurant|
        restaurant.name.downcase.include?(query.downcase)
      end
    end
  
    def rating_from(from)
      filter do |restaurant|
        restaurant.rating >= from
      end
    end
    
    def open_now
      now = Time.current
      
      filter do |restaurant|
        now.between? Time.parse(restaurant.opens_at), Time.parse(restaurant.closes_at)
      end
    end
  end
end

class Restaurant < ActiveRecord::Base
  def self.all
    [Restaurant.new(rating: 1, name: "Blue Bakery", opens_at: "6:00", closes_at: "14:00"),
     Restaurant.new(rating: 4, name: "Golden Bar & Grill", opens_at: "11:00", closes_at: "19:00"),
     Restaurant.new(rating: 2, name: "Smokestack Burger", opens_at: "9:00", closes_at: "23:00"),
     Restaurant.new(rating: 5, name: "Thirsty Juice Bar", opens_at: "8:00", closes_at: "18:00")]
  end
  
  def opening_hours
    "#{opens_at}-#{closes_at}"
  end
end

class RestaurantFilter < BaseFilter
  using RestaurantRefinements
  attribute :query, :string, default: ""
  attribute :rating, :integer, default: 1
  attribute :open_now, :boolean, default: false

  def apply!(chain)
    chain = chain.search(query) if query.present?
    chain = chain.rating_from(rating)
    chain = chain.open_now if open_now
    chain
  end

  def merge!(attribute, value)
    super

    if attribute == :open_now
      send(:open_now, !value)
    else
      send(:"#{attribute}=", value)
    end

    @_session[:filters]["Restaurant"].merge!(attribute => send(attribute))
  end
end