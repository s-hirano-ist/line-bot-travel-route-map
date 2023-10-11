# frozen_string_literal: true

class GeoApiService
  ZIPCODE_LENGTH = 7
  NUMBER = /\A[0-9]+\z/

  RADIUS = 6378.137
  SPEED_OF_MOVEMENT = 50 / 3.6 # ヘリコプターの移動速度 [km/h] --> [m/s]

  MIN_PARAMETERS = 2

  def generate_location_list(zipcode)
    require "httpclient"

    client    = HTTPClient.new
    url       = URI("http://geoapi.heartrails.com/api/json")
    url.query = {
      method: "searchByPostal", postal: zipcode
    }.to_param

    response  = client.get(url)
    res_json  = JSON.parse(response.body)

    raise Services::ApiUnknownException.new() if response.status != 200
    # 郵便番号が登録されていないとき、statusは200だが、bodyにエラーメッセージを返却
    raise Services::NotFoundException.new("zipcode") if res_json["response"].has_key?("error")

    {
      location: zipcode,
      latitude: res_json["response"]["location"][0]["y"],
      longitude: res_json["response"]["location"][0]["x"]
    }
  end

  def location_to_time(location_from, location_to)
    # REF: https://techblog.kyamanak.com/entry/2017/07/09/164052
    x1 = location_to[:latitude].to_f * Math::PI / 180
    y1 = location_to[:longitude].to_f * Math::PI / 180
    x2 = location_from[:latitude].to_f * Math::PI / 180
    y2 = location_from[:longitude].to_f * Math::PI / 180

    diff_y = (y1 - y2).abs

    calc1 = Math.cos(x2) * Math.sin(diff_y)
    calc2 = Math.cos(x1) * Math.sin(x2) - Math.sin(x1) * Math.cos(x2) * Math.cos(diff_y)

    numerator = Math.sqrt(calc1**2 + calc2**2)

    denominator = Math.sin(x1) * Math.sin(x2) + Math.cos(x1) * Math.cos(x2) * Math.cos(diff_y)

    degree = Math.atan2(numerator, denominator)

    distance = degree * RADIUS * 1000 # [m]

    {
      location_from: location_from[:location],
      location_to: location_to[:location],
      distance:,
      time: (distance / SPEED_OF_MOVEMENT)
    }
    end

  def format_input_message(received_message)
    # 全角 to 半角 UTF8
    # ハイフン削除
    # 空白区切り文字列　=> 配列
    require "nkf"
    NKF.nkf("-w -Z4", received_message).delete("-").split
  end

  def validate(zipcode_list)
    zipcode_list.each { |zipcode|
      raise Services::ValidationException.new("zipcode_format") if !(zipcode =~ NUMBER)
      raise Services::ValidationException.new("zipcode_length") if zipcode.length != ZIPCODE_LENGTH
    }
    raise Services::ValidationException.new("zipcode_parameter_length") if zipcode_list.length < MIN_PARAMETERS
  end
end
