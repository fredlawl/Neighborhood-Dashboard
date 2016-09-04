class Neighborhood < ActiveRecord::Base
  scope :search_by_name, -> (name) { where("name LIKE ?", name) }

  has_many :registered_vacant_lots

  # reverse_geocoded_by :latitude, :longitude
  # after_validation :reverse_geocode  # auto-fetch address
  has_and_belongs_to_many :coordinates
  accepts_nested_attributes_for :coordinates

  fuzzily_searchable :name

  def addresses
    return @addresses if @addresses.present?

    uri = URI::escape("http://dev-api.codeforkc.org//address-by-neighborhood/V0/#{name}?city=&state=mo")
    @addresses = JSON.parse(HTTParty.get(uri))
  rescue
    @addresses = {}
  end

  def crime_data
    Neighborhood::CrimeData.new(self)
  end

  def within_polygon_query(location_attribute)
    neighborhood_coordinates = coordinates.map{ |neighborhood|
      "#{neighborhood.longtitude} #{neighborhood.latitude}"
    }.join(',')

    "within_polygon(#{location_attribute}, 'MULTIPOLYGON (((#{neighborhood_coordinates})))')"
  end
end
