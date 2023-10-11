# frozen_string_literal: true

class GoogleMapsApiService
  MIN_PARAMETERS = 2
  MAX_PARAMETERS = 4

  def location_to_time(location_from, location_to)
    require "httpclient"

    client    = HTTPClient.new
    url       = URI("https://maps.googleapis.com/maps/api/distancematrix/json")
    url.query = {
      origins: location_from[:location],
      destinations: location_to[:location],
      language: "ja",
      key: ENV["GOOGLE_MAP_API_KEY"],
    }.to_param

    response  = client.get(url)
    res_json  = JSON.parse(response.body)

    raise Services::ApiUnknownException.new() if response.status != 200
    raise Services::NotFoundException.new("keyword") if res_json["rows"][0]["elements"][0]["status"] == "NOT_FOUND"

    {
      location_from: location_from[:location],
      location_to: location_to[:location],
      distance: res_json["rows"][0]["elements"][0]["distance"]["value"].to_f,
      time: res_json["rows"][0]["elements"][0]["duration"]["value"].to_f
    }
  end

  def generate_location_list(input)
    { location: input }
  end

  def format_input_message(received_message)
    # 全角空白 to 半角空白
    require "nkf"
    NKF.nkf("-Z1 -w", received_message).split
  end

  def validate(keyword_list)
    raise Services::ValidationException.new("google_maps_api_parameter_length") if keyword_list.length < MIN_PARAMETERS || keyword_list.length > MAX_PARAMETERS
  end
end
