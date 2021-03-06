class NeighborhoodServices::VacancyData::ThreeEleven
  DATA_SOURCE = '7at3-sxhp'
  DATA_SOURCE_URI = 'https://data.kcmo.org/311/311-Call-Center-Service-Requests/7at3-sxhp'
  POSSIBLE_FILTERS = ['vacant_structure', 'open']

  def initialize(neighborhood, three_eleven_filters = {})
    @neighborhood = neighborhood
    @three_eleven_filters = three_eleven_filters[:filters] || []
    @start_date = three_eleven_filters[:start_date]
    @end_date = three_eleven_filters[:end_date]
  end

  def data
    return @data unless @data.nil?

    querable_dataset = POSSIBLE_FILTERS.any? { |filter|
      @three_eleven_filters.include? filter
    }

    if querable_dataset
      @data ||= query_dataset
    else
      @data ||= []
    end
  end

  private

  def query_dataset
    three_eleven_data = SocrataClient.get(DATA_SOURCE, build_socrata_query)

    three_eleven_filtered_data(three_eleven_data)
      .values
      .select { |parcel|
        parcel["address_with_geocode"].present? && parcel["address_with_geocode"]["latitude"].present?
      }
      .map { |parcel|
        {
          "type" => "Feature",
          "geometry" => {
            "type" => "Point",
            "coordinates" => [parcel["address_with_geocode"]["longitude"].to_f, parcel["address_with_geocode"]["latitude"].to_f]
          },
          "properties" => {
            "parcel_number" => parcel['parcel_number'],
            "color" => '#ffffff',
            "disclosure_attributes" => all_disclosure_attributes(parcel)
          }
        }
      }
  end

  def build_socrata_query
    query_string = "SELECT * where neighborhood = '#{@neighborhood.name}'"
    query_elements = []

    if @three_eleven_filters.include?('vacant_structure')
      query_elements << "request_type='Nuisance Violations on Private Property Vacant Structure'"
      query_elements  << "request_type='Vacant Structure Open to Entry'"
    end

    if @three_eleven_filters.include?('open')
      query_elements << "status='OPEN'"
    end

    if query_elements.present?
      query_string += " AND (#{query_elements.join(' or ')})"
    end

    if @start_date && @end_date
      begin
        query_string += " AND creation_date >= '#{DateTime.parse(@start_date).iso8601[0...-6]}'"
        query_string += " AND creation_date <= '#{DateTime.parse(@end_date).iso8601[0...-6]}'"
      rescue
      end
    end

    query_string
  end

  def three_eleven_filtered_data(parcel_data)
    three_eleven_filtered_data = {}

    if @three_eleven_filters.include?('vacant_structure')
      foreclosure_data = ::NeighborhoodServices::VacancyData::Filters::VacantStructure.new(parcel_data).filtered_data
      merge_data_set(three_eleven_filtered_data, foreclosure_data)
    end

    if @three_eleven_filters.include?('open')
      open_case_data = ::NeighborhoodServices::VacancyData::Filters::OpenThreeEleven.new(parcel_data).filtered_data
      merge_data_set(three_eleven_filtered_data, open_case_data)
    end

    three_eleven_filtered_data
  end

  def merge_data_set(data, data_set)
    data_set.each do |entity|
      if data[entity['parcel_id_no']]
        data[entity['parcel_id_no']]['disclosure_attributes'] += entity['disclosure_attributes']
      else
        data[entity['parcel_id_no']] = entity
      end
    end
  end

  def all_disclosure_attributes(violation)
    disclosure_attributes = violation['disclosure_attributes'].try(&:uniq) || []
    title = "<h3 class='info-window-header'>Three Eleven Data:</h3>&nbsp;<a href='#{DATA_SOURCE_URI}'>Source</a>"
    last_updated = "Last Updated Date: #{last_updated_date}"
    address = "<b>Address:</b>&nbsp;#{JSON.parse(violation['address_with_geocode']['human_address'])['address'].titleize}"
    [title, last_updated, address] + disclosure_attributes
  end

  private

  def last_updated_date
    metadata = JSON.parse(HTTParty.get('https://data.kcmo.org/api/views/7at3-sxhp/').response.body)
    DateTime.strptime(metadata['viewLastModified'].to_s, '%s').strftime('%m/%d/%Y')
  rescue
    'N/A'
  end
end
