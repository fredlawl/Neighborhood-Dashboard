class NeighborhoodServices::VacancyData::Filters::BoardedLongterm
  def initialize(three_eleven_data)
    @three_eleven_data = three_eleven_data.dup
  end

  def filtered_data
    @three_eleven_data
      .select { |three_eleven_violation|
        three_eleven_violation['violation_code'] == 'NSBOARD01'
      }
      .each { |three_eleven_violation|
        three_eleven_violation['disclosure_attributes'] = [
          "Boarded and Vacant Over 150 Days"
        ]
      }
  end
end
