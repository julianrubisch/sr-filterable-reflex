# mimicks an ActiveRecord scope
module BookRefinements
  refine Array do
    def search(query)
      filter do |book|
        book.title.downcase.include?(query.downcase) || book.author.downcase.include?(query.downcase)
      end
    end
  end
end

class Book < ActiveRecord::Base
  def self.all
    [Book.new(title: "Recursion", author: "Blake Crouch"), Book.new(title: "VALIS", author: "Philip K. Dick")]    
  end
end

class BookFilter < BaseFilter
  using BookRefinements
  attribute :query, :string, default: ""

  def apply!(chain)
    chain = chain.search(query) if query.present?
    chain
  end

  def merge!(attribute, value)
    super

    send(:"#{attribute}=", value)

    @_session[:filters]["Book"].merge!(attribute => send(attribute))
  end
end