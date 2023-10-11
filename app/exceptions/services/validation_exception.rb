# frozen_string_literal: true

class Services::ValidationException < StandardError
  attr_reader :message_for_user
  def initialize(type)
    case type
    when "zipcode_length"
      @message_for_user = "スペース区切りで#{GeoApiService::ZIPCODE_LENGTH}桁の郵便番号を入力してね。"
    when "zipcode_parameter_length"
      @message_for_user = "郵便番号は２つ以上入力してね。"
    when "zipcode_format"
      @message_for_user = "郵便番号は数字で入力してね。"
    when "google_maps_api_parameter_length"
      @message_for_user = "スペース区切りで#{GoogleMapsApiService::MIN_PARAMETERS}個以上、#{GoogleMapsApiService::MAX_PARAMETERS}個以下の目的地数にしてね。"
    end
    super()
  end
end
