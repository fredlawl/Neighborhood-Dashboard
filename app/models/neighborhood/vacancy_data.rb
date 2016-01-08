class Neighborhood::VacancyData
  def initialize(neighborhood)
    @neighborhood = neighborhood
  end

  def dangerous_buildings
    request_url = URI::escape("https://data.kcmo.org/resource/w6zu-4g2q.json?$where=neighborhood = '#{@neighborhood.name}'")
    mapify_coordinates(HTTParty.get(request_url, verify: false))
  end

  private

  def mapify_coordinates(coordinates)
    # Not every coordinate is guaraneed to have location_1 populated with coordinates
    coordinates
      .select{ |coordinate|
        coordinate["location_1"].present? && coordinate["location_1"]["latitude"].present?
      }
      .map { |coordinate|
        {
          "property_class" => coordinate['property_class'],
          "type" => "Feature",
          "geometry" => {
            "type" => "Point",
            "coordinates" => [coordinate['location_1']['longitude'].to_f,coordinate['location_1']['latitude'].to_f]
          },
          "properties" => {
            "marker-color" => "#f28729",
            "marker-size" => "small"
          }
        }
      }
  end

  # TODO: Fix API to use this value
  def query_polygon
    coordinates = @neighborhood.coordinates.map{ |neighborhood|
      "#{neighborhood.latitude} #{neighborhood.longtitude}"
    }.join(',')

    "within_polygon(location_1, 'MULTIPOLYGON (((#{coordinates})))')"
  end
end