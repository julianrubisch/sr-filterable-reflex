class BaseFilter
  include ActiveModel::Model
  include ActiveModel::Attributes

  def initialize(session)
    @_session = session
    super(@_session.fetch(:filters, {})[filter_resource_class])
  end

  def apply!(_chain)
    raise NotImplementedError
  end

  def merge!(_attribute, _value)
    @_session[:filters] ||= {}
    @_session[:filters][filter_resource_class] ||= {}
  end

  def active_for?(attribute, value=true)
    filter_attribute = send(attribute)

    return filter_attribute.include?(value) if filter_attribute.is_a?(Enumerable)
    filter_attribute == value
  end

  def filter_resource_class
    @filter_resource_class || self.class.name.match(/\A(?<resource>.*)Filter\Z/)[:resource]
  end
end
